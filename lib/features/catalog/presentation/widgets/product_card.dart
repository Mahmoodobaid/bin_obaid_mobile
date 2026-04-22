// product_card.dart
// بطاقة المنتج - نسخة احترافية نهائية
// تدعم: صور متعددة (Carousel)، سعر الجملة/التجزئة، مخزون منخفض،
// زر مشاركة سريع، وضع مظلم، Hero انتقال، تأثيرات لمس، وشريط حالة المخزون.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../models/product_model.dart';
import '../../../../models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProductCard extends ConsumerStatefulWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  ConsumerState<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<ProductCard> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.97,
      upperBound: 1.0,
    );
    _scaleAnimation = CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) => _scaleController.forward();
  void _onTapUp(TapUpDetails details) => _scaleController.reverse();
  void _onTapCancel() => _scaleController.reverse();

  Future<void> _shareProduct() async {
    try {
      final product = widget.product;
      final user = ref.read(authProvider).currentUser;
      final price = _getDisplayPrice(product, user);
      final shareText = '''
🛍️ *${product.name}*
🔖 SKU: ${product.sku}
💰 السعر: $price
📦 المخزون: ${product.stockQuantity > 0 ? 'متوفر (${product.stockQuantity} قطعة)' : 'نفد المخزون'}
🏷️ التصنيف: ${product.category ?? 'غير محدد'}
${product.description != null ? '\n📝 ${product.description}' : ''}
📍 تطبيق بن عبيد التجارية
''';
      await Share.share(shareText, subject: product.name);
      HapticFeedback.lightImpact();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في المشاركة: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _getDisplayPrice(Product product, UserModel? user) {
    if (user == null) return 'سجل للدخول';
    if (user.role == 'customer' && product.wholesalePrice != null) {
      return '${product.wholesalePrice!.toStringAsFixed(2)} ريال (جملة)';
    }
    return '${product.unitPrice.toStringAsFixed(2)} ريال';
  }

  bool _isLowStock() => widget.product.minStock != null && widget.product.stockQuantity <= widget.product.minStock!;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageUrls = widget.product.imageUrls;
    final hasMultipleImages = imageUrls.length > 1;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: () => context.push('/product/${widget.product.sku}'),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // قسم الصورة (مع Carousel إذا وُجدت عدة صور)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: _buildImageCarousel(imageUrls, hasMultipleImages),
                    ),
                  ),
                  // زر المشاركة السريع (مع تحسين الشكل)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.white.withOpacity(0.9),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: _shareProduct,
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.share_outlined, size: 18, color: Colors.green),
                        ),
                      ),
                    ),
                  ),
                  // علامة "جملة" إذا كان المستخدم تاجراً وسعر الجملة موجود
                  if (user?.role == 'customer' && widget.product.wholesalePrice != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade700,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'جملة',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  // مؤشر المخزون المنخفض
                  if (_isLowStock())
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'مخزون محدود',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              // معلومات المنتج
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.product.sku,
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _getDisplayPrice(widget.product, user),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.product.stockQuantity > 0 ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.product.stockQuantity > 0 ? 'متوفر' : 'نفد',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: widget.product.stockQuantity > 0 ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageCarousel(List<String> imageUrls, bool hasMultipleImages) {
    if (imageUrls.isEmpty) {
      return Image.asset('assets/images/default.png', fit: BoxFit.cover);
    }
    if (!hasMultipleImages) {
      return CachedNetworkImage(
        imageUrl: imageUrls.first,
        fit: BoxFit.cover,
        placeholder: (_, __) => Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(color: Colors.white),
        ),
        errorWidget: (_, __, ___) => Image.asset('assets/images/default.png', fit: BoxFit.cover),
      );
    }
    // Carousel لعدة صور مع مؤشر صفحات
    return Stack(
      children: [
        PageView.builder(
          itemCount: imageUrls.length,
          onPageChanged: (index) => setState(() => _currentImageIndex = index),
          itemBuilder: (context, index) => CachedNetworkImage(
            imageUrl: imageUrls[index],
            fit: BoxFit.cover,
            placeholder: (_, __) => Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Container(color: Colors.white),
            ),
            errorWidget: (_, __, ___) => Image.asset('assets/images/default.png', fit: BoxFit.cover),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              imageUrls.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentImageIndex == index ? 8 : 5,
                height: 5,
                decoration: BoxDecoration(
                  color: _currentImageIndex == index ? Colors.white : Colors.white70,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}