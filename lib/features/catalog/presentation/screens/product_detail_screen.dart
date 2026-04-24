import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  Product? _product; bool _loading = true; int _qty = 1;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final api = ref.read(apiServiceProvider);
    final p = await api.fetchProductBySku(widget.sku);
    if (mounted) setState(() { _product = p; _loading = false; });
  }
  Future<void> _share() async {
    if (_product == null) return;
    final img = await _screenshot.captureFromWidget(_collage(), delay: const Duration(milliseconds: 100));
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/product_${_product!.sku}.png');
    await file.writeAsBytes(img);
    await Share.shareXFiles([XFile(file.path)], text: 'شاهد ${_product!.name} في محلات بن عبيد');
  }
  Widget _collage() => Material(child: Directionality(textDirection: TextDirection.rtl, child: Container(width: 500, color: Colors.white, padding: const EdgeInsets.all(20), child: Column(children: [Text(_product!.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), if (_product!.imageUrls.isNotEmpty) CachedNetworkImage(imageUrl: _product!.imageUrls.first, height: 200), Text('${_product!.unitPrice} ريال', style: const TextStyle(fontSize: 28, color: Colors.green))]))));
  void _add() { if (_product == null) return; for (int i = 0; i < _qty; i++) ref.read(cartProvider.notifier).addItem(_product!); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تمت الإضافة'), backgroundColor: Colors.green)); }
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_product == null) return Scaffold(appBar: AppBar(title: const Text('غير موجود')), body: const Center(child: Text('لم يتم العثور')));
    final prod = _product!;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(prod.name), actions: [IconButton(icon: const Icon(Icons.share), onPressed: _share)]),
        body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (prod.imageUrls.isNotEmpty) CachedNetworkImage(imageUrl: prod.imageUrls.first, height: 250, fit: BoxFit.contain),
          const SizedBox(height: 16), Text(prod.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text('SKU: ${prod.sku}'), const Divider(),
          Text('${prod.unitPrice} ريال', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 24),
          Row(children: [
            const Text('الكمية:'), const SizedBox(width: 16),
            Container(decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)), child: Row(children: [
              IconButton(icon: const Icon(Icons.remove), onPressed: () => setState(() { if (_qty > 1) _qty--; })),
              Text('$_qty', style: const TextStyle(fontSize: 18)),
              IconButton(icon: const Icon(Icons.add), onPressed: () => setState(() => _qty++)),
            ])),
          ]),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: ElevatedButton.icon(onPressed: _add, icon: const Icon(Icons.add_shopping_cart), label: const Text('أضف للسلة'))),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(onPressed: _share, icon: const Icon(Icons.share), label: const Text('مشاركة'))),
          ]),
        ])),
      ),
    );
  }
}
