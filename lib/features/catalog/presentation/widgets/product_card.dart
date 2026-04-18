import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../models/product_model.dart';
import '../../../../models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProductCard extends ConsumerWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).currentUser;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/product/${product.sku}'),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Hero(
                  tag: product.sku,
                  child: product.imageUrls.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrls.first,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => Shimmer.fromColors(
                            baseColor: Colors.grey.shade300,
                            highlightColor: Colors.grey.shade100,
                            child: Container(color: Colors.white),
                          ),
                          errorWidget: (_, __, ___) => Image.asset('assets/images/default.png', fit: BoxFit.contain),
                        )
                      : Image.asset('assets/images/default.png', fit: BoxFit.contain),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(product.sku, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const Spacer(),
                    Text(
                      _getDisplayPrice(product, user),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F3BBF)),
                    ),
                    Text(
                      product.stockQuantity > 0 ? 'متوفر' : 'نفذ المخزون',
                      style: TextStyle(fontSize: 11, color: product.stockQuantity > 0 ? Colors.green : Colors.red),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDisplayPrice(Product product, UserModel? user) {
    if (user == null) return 'سجل الدخول';
    if (user.role == 'customer' && product.wholesalePrice != null) {
      return '${product.wholesalePrice!.toStringAsFixed(2)} ريال';
    }
    return '${product.unitPrice.toStringAsFixed(2)} ريال';
  }
}
