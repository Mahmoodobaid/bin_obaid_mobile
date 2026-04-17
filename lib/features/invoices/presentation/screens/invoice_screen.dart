import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/invoice_provider.dart';
import '../../../catalog/presentation/providers/product_provider.dart';
import '../../../../services/api_service.dart';
import '../../../../models/product_model.dart';

class InvoiceScreen extends ConsumerStatefulWidget {
  const InvoiceScreen({super.key});
  @override
  ConsumerState<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends ConsumerState<InvoiceScreen> {
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _discountController = TextEditingController();
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _discountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showProductSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Consumer(
          builder: (context, ref, child) {
            final searchQuery = ref.watch(_searchProvider);
            final productsAsync = ref.watch(searchProductsProvider(searchQuery));
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'ابحث عن منتج بالاسم أو SKU...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear), onPressed: () => ref.read(_searchProvider.notifier).state = '')
                          : null,
                    ),
                    onChanged: (v) => ref.read(_searchProvider.notifier).state = v,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: productsAsync.when(
                      data: (products) => products.isEmpty
                          ? const Center(child: Text('لا توجد منتجات تطابق البحث'))
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: products.length,
                              itemBuilder: (ctx, i) {
                                final p = products[i];
                                return ListTile(
                                  leading: p.imageUrls.isNotEmpty
                                      ? Image.network(p.imageUrls.first, width: 40, height: 40, fit: BoxFit.cover)
                                      : const Icon(Icons.image),
                                  title: Text(p.name),
                                  subtitle: Text('SKU: ${p.sku} | السعر: ${p.unitPrice.toStringAsFixed(2)} ريال'),
                                  trailing: p.stockQuantity > 0
                                      ? ElevatedButton.icon(
                                          icon: const Icon(Icons.add, size: 18),
                                          label: const Text('إضافة'),
                                          onPressed: () {
                                            ref.read(invoiceProvider.notifier).addProduct(p);
                                            Navigator.pop(context);
                                          },
                                        )
                                      : const Text('نفذ', style: TextStyle(color: Colors.red)),
                                );
                              },
                            ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text('خطأ: $err')),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _saveInvoice() async {
    final api = ref.read(apiServiceProvider);
    final inv = ref.read(invoiceProvider);
    final data = {
      'invoice_number': 'INV-${DateTime.now().millisecondsSinceEpoch}',
      'customer_name': _customerNameController.text,
      'customer_phone': _customerPhoneController.text,
      'subtotal': inv.subtotal,
      'discount': inv.discount,
      'tax_amount': inv.taxAmount,
      'total_amount': inv.finalTotal,
      'items': inv.items.map((i) => {'sku': i.product.sku, 'quantity': i.quantity, 'unit_price': i.unitPrice}).toList(),
    };
    await api.createInvoice(data);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم حفظ الفاتورة بنجاح'), backgroundColor: Colors.green));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = ref.watch(invoiceProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('فاتورة جديدة'),
          actions: [
            IconButton(icon: const Icon(Icons.save), onPressed: _saveInvoice),
            IconButton(icon: const Icon(Icons.print), onPressed: () {}),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(controller: _customerNameController, decoration: const InputDecoration(labelText: 'اسم العميل')),
                      const SizedBox(height: 8),
                      TextField(controller: _customerPhoneController, decoration: const InputDecoration(labelText: 'رقم الهاتف'), keyboardType: TextInputType.phone),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Card(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: const [
                            Expanded(flex: 3, child: Text('المنتج', style: TextStyle(fontWeight: FontWeight.bold))),
                            Expanded(child: Text('الكمية', style: TextStyle(fontWeight: FontWeight.bold))),
                            Expanded(child: Text('السعر', style: TextStyle(fontWeight: FontWeight.bold))),
                            SizedBox(width: 40),
                          ],
                        ),
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView.builder(
                          itemCount: inv.items.length,
                          itemBuilder: (c, i) {
                            final item = inv.items[i];
                            return ListTile(
                              title: Text(item.product.name),
                              subtitle: Text('${item.unitPrice.toStringAsFixed(2)} ريال'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.remove), onPressed: () => ref.read(invoiceProvider.notifier).decrementQuantity(i)),
                                  Text('${item.quantity}'),
                                  IconButton(icon: const Icon(Icons.add), onPressed: () => ref.read(invoiceProvider.notifier).incrementQuantity(i)),
                                  IconButton(icon: const Icon(Icons.delete), onPressed: () => ref.read(invoiceProvider.notifier).removeItem(i)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      ListTile(
                        leading: ElevatedButton.icon(onPressed: _showProductSearch, icon: const Icon(Icons.add), label: const Text('إضافة منتج')),
                        trailing: Text('الإجمالي: ${inv.subtotal.toStringAsFixed(2)} ريال', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextField(controller: _discountController, decoration: const InputDecoration(labelText: 'الخصم'), onChanged: (v) => ref.read(invoiceProvider.notifier).setDiscount(double.tryParse(v) ?? 0))),
                  const SizedBox(width: 16),
                  Expanded(child: Text('الضريبة: ${inv.taxAmount.toStringAsFixed(2)} ريال')),
                  const SizedBox(width: 16),
                  Expanded(child: Text('الإجمالي النهائي: ${inv.finalTotal.toStringAsFixed(2)} ريال', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final _searchProvider = StateProvider<String>((ref) => '');
final searchProductsProvider = FutureProvider.family<List<Product>, String>((ref, query) async {
  if (query.isEmpty) return [];
  return await ref.read(apiServiceProvider).searchProducts(query: query);
});
