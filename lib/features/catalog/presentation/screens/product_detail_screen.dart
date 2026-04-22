// product_detail_screen.dart
// شاشة تفاصيل المنتج - نسخة احترافية نهائية
// المسار: lib/features/catalog/presentation/screens/product_detail_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:intl/intl.dart';

import '../../../../models/product_model.dart';
import '../../../../models/user_model.dart';
import '../../../../services/api_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../widgets/quantity_selector.dart';
import '../../widgets/product_image_gallery.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String sku;
  const ProductDetailScreen({super.key, required this.sku});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  Product? _product;
  bool _isLoading = true;
  String? _errorMessage;
  int _quantity = 1;
  final ScreenshotController _screenshotController = ScreenshotController();
  int _selectedImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final product = await api.fetchProductBySku(widget.sku);
      if (mounted) {
        setState(() {
          _product = product;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _getDisplayPrice(UserModel? user) {
    if (_product == null) return '';
    if (user == null) return 'سجل الدخول لعرض السعر';
    if (user.role == 'customer' && _product!.wholesalePrice != null) {
      return '${NumberFormat('#,##0.00').format(_product!.wholesalePrice)} ريال (جملة)';
    }
    return '${NumberFormat('#,##0.00').format(_product!.unitPrice)} ريال';
  }

  String _getOriginalPrice() {
    if (_product == null) return '';
    if (_product!.wholesalePrice != null && _product!.unitPrice > _product!.wholesalePrice!) {
      return '${NumberFormat('#,##0.00').format(_product!.unitPrice)} ريال';
    }
    return '';
  }

  bool _hasDiscount() {
    if (_product == null) return false;
    final user = ref.read(authProvider).currentUser;
    if (user?.role == 'customer' && _product!.wholesalePrice != null) {
      return _product!.unitPrice > _product!.wholesalePrice!;
    }
    return false;
  }

  Future<void> _shareProduct() async {
    if (_product == null) return;
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final image = await _screenshotController.captureFromWidget(
        _buildShareCollage(),
        delay: const Duration(milliseconds: 100),
      );
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/product_${_product!.sku}.png');
      await file.writeAsBytes(image);
      if (mounted) Navigator.pop(context);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '🛍️ ${_product!.name}\n💰 ${_getDisplayPrice(ref.read(authProvider).currentUser)}\n🔖 SKU: ${_product!.sku}\n\nللتسوق: تطبيق بن عبيد',
        subject: _product!.name,
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل المشاركة: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildShareCollage() {
    final product = _product!;
    final user = ref.read(authProvider).currentUser;
    final priceText = _getDisplayPrice(user);
    return Material(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          width: 500,
          color: Colors.white,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1B2A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('بن عبيد', style: TextStyle(color: Color(0xFFDCC86E), fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('محلات بن عبيد التجارية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Bin Obaid Trading Stores', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              // صورة المنتج
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.grey.shade100,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: product.imageUrls.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrls.first,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                          errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported, size: 50),
                        )
                      : Image.asset('assets/images/default.png', fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 16),
              // معلومات المنتج
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('SKU: ${product.sku}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    if (product.category != null) ...[
                      const SizedBox(height: 4),
                      Text('التصنيف: ${product.category}', style: const TextStyle(fontSize: 12)),
                    ],
                    const SizedBox(height: 12),
                    Text(priceText, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                    if (_hasDiscount())
                      Text(
                        'السعر الأصلي: ${_getOriginalPrice()}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.lineThrough),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('📍 للطلب: 770491653', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              const Text('تطبيق بن عبيد - تسوق بثقة', style: TextStyle(fontSize: 10, color: Colors.grey)),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ تمت إضافة $_quantity ${_product!.unit ?? 'قطعة'} من ${_product!.name} إلى السلة'),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('جاري تحميل المنتج...', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('المنتج غير موجود')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                'لم يتم العثور على المنتج\nSKU: ${widget.sku}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('رجوع'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _loadProduct,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final product = _product!;
    final user = authState.currentUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FA),
        appBar: _buildAppBar(product, isDark),
        body: Screenshot(
          controller: _screenshotController,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // معرض الصور
                    ProductImageGallery(
                      imageUrls: product.imageUrls,
                      height: 300,
                      onIndexChanged: (index) => setState(() => _selectedImageIndex = index),
                    ),
                    const SizedBox(height: 16),
                    // معلومات المنتج
                    _buildInfoSection(product, user, isDark),
                    const SizedBox(height: 24),
                    // وصف المنتج
                    if (product.description != null && product.description!.isNotEmpty)
                      _buildDescriptionSection(product, isDark),
                    const SizedBox(height: 24),
                    // تفاصيل إضافية
                    _buildDetailsSection(product, isDark),
                    const SizedBox(height: 24),
                    // السعر والكمية والإجراءات
                    _buildPriceAndActions(product, user, isDark),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(Product product, bool isDark) {
    return AppBar(
      title: Text(product.name, style: const TextStyle(fontSize: 18)),
      centerTitle: true,
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      foregroundColor: isDark ? Colors.white : Colors.black87,
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined),
          onPressed: _shareProduct,
          tooltip: 'مشاركة',
        ),
        IconButton(
          icon: const Icon(Icons.shopping_cart_outlined),
          onPressed: () => context.push('/cart'),
          tooltip: 'السلة',
        ),
      ],
    );
  }

  Widget _buildInfoSection(Product product, UserModel? user, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('SKU: ${product.sku}', style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              if (product.category != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(product.category!, style: const TextStyle(fontSize: 12, color: Colors.blue)),
                ),
            ],
          ),
          if (product.barcode != null && product.barcode!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('الباركود: ${product.barcode}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(Product product, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.description_outlined, size: 20),
              SizedBox(width: 8),
              Text('الوصف', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            product.description!,
            style: const TextStyle(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(Product product, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, size: 20),
              SizedBox(width: 8),
              Text('تفاصيل إضافية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          _buildDetailRow('وحدة القياس', product.unit ?? 'قطعة'),
          _buildDetailRow('الكمية المتاحة', '${product.stockQuantity.toStringAsFixed(0)}'),
          if (product.location != null) _buildDetailRow('موقع التخزين', product.location!),
          if (product.notes != null) _buildDetailRow('ملاحظات', product.notes!),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceAndActions(Product product, UserModel? user, bool isDark) {
    final priceText = _getDisplayPrice(user);
    final hasDiscount = _hasDiscount();
    final isLoggedIn = user != null;
    final isInStock = product.stockQuantity > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // السعر
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      priceText,
                      style: TextStyle(
                        fontSize: hasDiscount ? 28 : 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    if (hasDiscount)
                      Text(
                        _getOriginalPrice(),
                        style: const TextStyle(fontSize: 16, color: Colors.grey, decoration: TextDecoration.lineThrough),
                      ),
                  ],
                ),
              ),
              if (isLoggedIn && isInStock)
                QuantitySelector(
                  quantity: _quantity,
                  onChanged: (value) => setState(() => _quantity = value),
                  min: 1,
                  max: product.stockQuantity.toInt(),
                ),
            ],
          ),
          const SizedBox(height: 20),
          // أزرار الإجراءات
          if (isLoggedIn && isInStock) ...[
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _addToCart,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('أضف إلى السلة'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareProduct,
                    icon: const Icon(Icons.share),
                    label: const Text('مشاركة'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (!isLoggedIn) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/login'),
                icon: const Icon(Icons.login),
                label: const Text('سجل الدخول للشراء'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ] else if (!isInStock) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Center(
                child: Text('⚠️ المنتج غير متوفر حالياً', style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}