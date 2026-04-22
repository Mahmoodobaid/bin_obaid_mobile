// shimmer_product_card.dart
// بطاقة تحميل متألقة (Shimmer) - نسخة احترافية نهائية
// تُستخدم أثناء تحميل البيانات لعرض وهمي أنيق وجذاب.

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerProductCard extends StatelessWidget {
  final bool isDarkMode;
  final int? crossAxisCount; // لتحديد حجم الخط أو التخطيط حسب عدد الأعمدة (اختياري)

  const ShimmerProductCard({
    super.key,
    this.isDarkMode = false,
    this.crossAxisCount,
  });

  @override
  Widget build(BuildContext context) {
    // تحديد الألوان المناسبة للوضع المظلم أو الفاتح
    final baseColor = isDarkMode
        ? Colors.grey.shade800
        : Colors.grey.shade300;
    final highlightColor = isDarkMode
        ? Colors.grey.shade600
        : Colors.grey.shade100;

    // تعديل حجم الخط قليلاً حسب عدد الأعمدة (إذا كان معروفاً)
    final double nameHeight = crossAxisCount == 2 ? 18 : 16;
    final double skuHeight = crossAxisCount == 2 ? 14 : 12;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: const Duration(milliseconds: 1500),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // مساحة الصورة
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey.shade900 : Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
              ),
            ),
            // مساحة النصوص
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // اسم المنتج
                    Container(
                      height: nameHeight,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey.shade900 : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // SKU
                    Container(
                      height: skuHeight,
                      width: 80,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey.shade900 : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const Spacer(),
                    // السعر والسعر المخفض
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // السعر الرئيسي
                        Container(
                          height: 20,
                          width: 70,
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.grey.shade900 : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        // حالة المخزون (متوفر / غير متوفر)
                        Container(
                          height: 16,
                          width: 50,
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.grey.shade900 : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
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
}