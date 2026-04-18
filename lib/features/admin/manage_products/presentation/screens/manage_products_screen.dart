import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../presentation/providers/admin_request_provider.dart';
import '../../../../../models/product_model.dart';
import '../../../../../services/api_service.dart';

class ManageProductsScreen extends ConsumerStatefulWidget {
  const ManageProductsScreen({super.key});

  @override
  ConsumerState<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends ConsumerState<ManageProductsScreen> {
  final _searchController = TextEditingController();
  List<Product> _products = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final fetched = await api.fetchProducts(page: 1, pageSize: 1000);
      setState(() {
        _products = fetched;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في التحميل: $e')));
    }
  }

  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    return _products.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()) || p.sku.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  void _showProductDialog(Product? product) {
    final nameController = TextEditingController(text: product?.name);
    final skuController = TextEditingController(text: product?.sku);
    final priceController = TextEditingController(text: product?.unitPrice.toString());
    final stockController = TextEditingController(text: product?.stockQuantity.toString());
    final categoryController = TextEditingController(text: product?.category);
    final unitController = TextEditingController(text: product?.unit);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product == null ? 'إضافة منتج جديد' : 'تعديل المنتج'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم المنتج')),
              TextField(controller: skuController, decoration: const InputDecoration(labelText: 'SKU')),
              TextField(controller: priceController, decoration: const InputDecoration(labelText: 'السعر'), keyboardType: TextInputType.number),
              TextField(controller: stockController, decoration: const InputDecoration(labelText: 'المخزون'), keyboardType: TextInputType.number),
              TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'الفئة')),
              TextField(controller: unitController, decoration: const InputDecoration(labelText: 'الوحدة (حبة، كرتون...)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final api = ref.read(apiServiceProvider);
              final data = {
                'sku': skuController.text,
                'name': nameController.text,
                'unit_price': double.tryParse(priceController.text) ?? 0.0,
                'stock_quantity': int.tryParse(stockController.text) ?? 0,
                'category': categoryController.text,
                'unit': unitController.text,
                'last_updated': DateTime.now().toIso8601String(),
              };
              if (product == null) {
                await api.insertRecord('products', data);
              } else {
                await api.updateRecord('products', {'sku': product.sku}, data);
              }
              Navigator.pop(ctx);
              _loadProducts();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف "${product.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed == true) {
      final api = ref.read(apiServiceProvider);
      await api.deleteRecord('products', {'sku': product.sku});
      _loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة المنتجات'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadProducts),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'بحث بالاسم أو SKU...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _searchController.clear(); _searchQuery = ''; })) : null,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey), const SizedBox(height: 16), Text(_products.isEmpty ? 'لا توجد منتجات' : 'لا توجد نتائج للبحث')]))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: filtered.length,
                          itemBuilder: (c, i) {
                            final p = filtered[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(child: Text(p.name.isNotEmpty ? p.name[0] : 'P')),
                                title: Text(p.name),
                                subtitle: Text('SKU: ${p.sku} | السعر: ${p.unitPrice} | المخزون: ${p.stockQuantity}'),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showProductDialog(p)),
                                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteProduct(p)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showProductDialog(null),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
