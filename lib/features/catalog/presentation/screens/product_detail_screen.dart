import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import '../../../../models/product_model.dart';
import '../../../../services/api_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../cart/presentation/providers/cart_provider.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String sku;
  const ProductDetailScreen({super.key, required this.sku});
  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  final ScreenshotController _screenshot = ScreenshotController();
  Product? _product;
  bool _isLoading = true;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    final api = ref.read(apiServiceProvider);
    final product = await api.fetchProductBySku(widget.sku);
    setState(() { _product = product; _isLoading = false; });
  }

  Future<void> _shareProduct() async {
    if (_product == null) return;
    final img = await _screenshot.captureFromWidget(_buildCollage(), delay: const Duration(milliseconds: 100));
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/product_${_product!.sku}.png');
    await file.writeAsBytes(img);
    await Share.shareXFiles([XFile(file.path)], text: 'شاهد ${_product!.name} في محلات بن عبيد');
  }

  Widget _buildCollage() => Material(
    child: Directionality(textDirection: TextDirection.rtl, child: Container(width: 600, color: Colors.white, padding: const EdgeInsets.all(20),
      child: Column(children: [Text(_product!.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 10), Text('${_product!.unitPrice} ريال', style: const TextStyle(fontSize: 28, color: Colors.green))]))));

  void _addToCart() {
    if (_product == null) return;
    for (int i = 0; i < _quantity; i++) ref.read(cartProvider.notifier).addItem(_product!);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تمت إضافة $_quantity ${_product!.unit} إلى السلة'), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_product == null) return Scaffold(appBar: AppBar(title: const Text('غير موجود')), body: const Center(child: Text('لم يتم العثور')));
    final product = _product!;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(product.name), actions: [IconButton(icon: const Icon(Icons.share), onPressed: _shareProduct)]),
        body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (product.imageUrls.isNotEmpty) CachedNetworkImage(imageUrl: product.imageUrls.first, height: 250, fit: BoxFit.contain),
          const SizedBox(height: 16),
          Text(product.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text('SKU: ${product.sku}'), const Divider(),
          Text('${product.unitPrice} ريال', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 24),
          Row(children: [const Text('الكمية:'), const SizedBox(width: 16), Container(decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)), child: Row(children: [IconButton(icon: const Icon(Icons.remove), onPressed: () => setState(() { if (_quantity > 1) _quantity--; })), Text('$_quantity', style: const TextStyle(fontSize: 18)), IconButton(icon: const Icon(Icons.add), onPressed: () => setState(() => _quantity++))]))]),
          const SizedBox(height: 24),
          Row(children: [Expanded(child: ElevatedButton.icon(onPressed: _addToCart, icon: const Icon(Icons.add_shopping_cart), label: const Text('أضف للسلة'))), const SizedBox(width: 12), Expanded(child: OutlinedButton.icon(onPressed: _shareProduct, icon: const Icon(Icons.share), label: const Text('مشاركة')))])
        ])),
      ),
    );
  }
}
