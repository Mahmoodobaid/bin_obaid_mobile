import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import '../../../../models/product_model.dart';
import '../../../../models/user_model.dart';
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
    setState(() {
      _product = product;
      _isLoading = false;
    });
  }

  String _getDisplayPrice(Product product, UserModel? user) {
    if (user == null) return 'سجل الدخول لعرض السعر';
    if (user.role == 'customer' && product.wholesalePrice != null) {
      return '${product.wholesalePrice!.toStringAsFixed(2)} ريال (جملة)';
    }
    return '${product.unitPrice.toStringAsFixed(2)} ريال';
  }

  Future<void> _shareProduct() async {
    if (_product == null) return;
    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      final image = await _screenshot.captureFromWidget(
        _buildShareCollage(),
        delay: const Duration(milliseconds: 100),
      );
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/product_${_product!.sku}.png');
      await file.writeAsBytes(image);
      if (mounted) Navigator.pop(context);
      await Share.shareXFiles([XFile(file.path)], text: 'شاهد ${_product!.name} في محلات بن عبيد التجارية');
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _buildShareCollage() {
    final product = _product!;
    final user = ref.read(authProvider).currentUser;
    return Material(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          width: 600,
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(width: 60, height: 60, decoration: BoxDecoration(color: const Color(0xFF0D1B2A), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.store, color: Color(0xFFDCC86E), size: 40)),
                const SizedBox(width: 12),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('محلات بن عبيد التجارية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text('Bin Obaid Trading Stores', style: TextStyle(fontSize: 14, color: Colors.grey))]),
              ]),
              const Divider(height: 30),
              Container(height: 250, child: product.imageUrls.isNotEmpty ? CachedNetworkImage(imageUrl: product.imageUrls.first, fit: BoxFit.contain) : Image.asset('assets/images/default.png')),
              const SizedBox(height: 20),
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(product.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('SKU: ${product.sku}', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                Text('السعر: ${_getDisplayPrice(product, user)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
              ])),
              const SizedBox(height: 20),
              const Text('للتواصل: 770491653', style: TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  void _addToCart() {
    if (_product == null) return;
    for (int i = 0; i < _quantity; i++) {
      ref.read(cartProvider.notifier).addItem(_product!);
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تمت إضافة $_quantity ${_product!.unit} من ${_product!.name} إلى السلة'), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_product == null) return Scaffold(appBar: AppBar(title: const Text('المنتج غير موجود')), body: const Center(child: Text('لم يتم العثور على المنتج')));
    final product = _product!;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(product.name), actions: [IconButton(icon: const Icon(Icons.share), onPressed: _shareProduct)]),
        body: Screenshot(
          controller: _screenshot,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 250,
                  child: product.imageUrls.isNotEmpty
                      ? CachedNetworkImage(imageUrl: product.imageUrls.first, fit: BoxFit.contain)
                      : Image.asset('assets/images/default.png', fit: BoxFit.contain),
                ),
                const SizedBox(height: 16),
                Text(product.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('SKU: ${product.sku}', style: TextStyle(color: Colors.grey[600])),
                const Divider(height: 32),
                Text(_getDisplayPrice(product, authState.currentUser), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
                const SizedBox(height: 24),
                if (authState.currentUser != null && product.stockQuantity > 0) ...[
                  Row(children: [const Text('الكمية:'), const SizedBox(width: 16), Container(decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)), child: Row(children: [IconButton(icon: const Icon(Icons.remove), onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null), Text('$_quantity', style: const TextStyle(fontSize: 18)), IconButton(icon: const Icon(Icons.add), onPressed: () => setState(() => _quantity++))]))]),
                  const SizedBox(height: 24),
                  Row(children: [Expanded(child: ElevatedButton.icon(onPressed: _addToCart, icon: const Icon(Icons.add_shopping_cart), label: const Text('أضف إلى السلة'))), const SizedBox(width: 12), Expanded(child: OutlinedButton.icon(onPressed: _shareProduct, icon: const Icon(Icons.share), label: const Text('مشاركة')))])
                ] else if (authState.currentUser == null) ...[
                  const SizedBox(height: 24),
                  SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => context.push('/login'), child: const Text('سجل الدخول للشراء'))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
