// product_model.dart
// نموذج المنتج المتكامل - يدعم Hive للتخزين المحلي والتحويل من/إلى JSON

import 'package:hive/hive.dart';

part 'product_model.g.dart'; // سيتم إنشاؤه بواسطة build_runner

@HiveType(typeId: 0) // معرف فريد لنوع الـ Hive
class Product {
  // ============================================================
  // الحقول الأساسية (معرفات فريدة)
  // ============================================================
  @HiveField(0)
  final String sku; // الرمز الفريد للمنتج (Primary Key)

  @HiveField(1)
  final String? barcode; // الباركود (اختياري)

  // ============================================================
  // المعلومات العامة
  // ============================================================
  @HiveField(2)
  final String name; // اسم المنتج

  @HiveField(3)
  final String? description; // وصف المنتج

  @HiveField(4)
  final String? category; // التصنيف

  @HiveField(5)
  final String? unit; // وحدة القياس (قطعة، كجم، لتر...)

  // ============================================================
  // الأسعار والمخزون
  // ============================================================
  @HiveField(6)
  final double unitPrice; // سعر الوحدة

  @HiveField(7)
  final double? wholesalePrice; // سعر الجملة (اختياري)

  @HiveField(8)
  final double stockQuantity; // الكمية المتاحة

  @HiveField(9)
  final double? minStock; // الحد الأدنى للمخزون (للتنبيه)

  // ============================================================
  // معلومات إضافية
  // ============================================================
  @HiveField(10)
  final String? location; // موقع التخزين

  @HiveField(11)
  final String? notes; // ملاحظات إضافية

  @HiveField(12)
  final List<String> imageUrls; // عناوين الصور (يدعم عدة صور)

  // ============================================================
  // التواريخ والحالة
  // ============================================================
  @HiveField(13)
  final DateTime createdAt; // تاريخ الإنشاء

  @HiveField(14)
  DateTime updatedAt; // آخر تحديث

  @HiveField(15)
  String syncStatus; // حالة المزامنة: 'synced', 'pending', 'failed'

  // ============================================================
  // حقل محسن للبحث السريع (يُولَّد تلقائياً)
  // ============================================================
  @HiveField(16)
  final String? searchTokens; // نص معالج للبحث (يحتوي على جميع الحقول المهمة)

  // ============================================================
  // المنشئ الرئيسي
  // ============================================================
  Product({
    required this.sku,
    this.barcode,
    required this.name,
    this.description,
    this.category,
    this.unit,
    required this.unitPrice,
    this.wholesalePrice,
    required this.stockQuantity,
    this.minStock,
    this.location,
    this.notes,
    required this.imageUrls,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'synced',
    this.searchTokens,
  });

  // ============================================================
  // دالة copyWith لإنشاء نسخة معدلة بسهولة
  // ============================================================
  Product copyWith({
    String? sku,
    String? barcode,
    String? name,
    String? description,
    String? category,
    String? unit,
    double? unitPrice,
    double? wholesalePrice,
    double? stockQuantity,
    double? minStock,
    String? location,
    String? notes,
    List<String>? imageUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncStatus,
    String? searchTokens,
  }) {
    return Product(
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minStock: minStock ?? this.minStock,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      imageUrls: imageUrls ?? List.from(this.imageUrls),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      searchTokens: searchTokens ?? this.searchTokens,
    );
  }

  // ============================================================
  // تحويل من JSON (عند الاستيراد من API)
  // ============================================================
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      sku: json['sku']?.toString() ?? '',
      barcode: json['barcode']?.toString(),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      category: json['category']?.toString(),
      unit: json['unit']?.toString(),
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      wholesalePrice: (json['wholesale_price'] as num?)?.toDouble(),
      stockQuantity: (json['stock_quantity'] as num?)?.toDouble() ?? 0.0,
      minStock: (json['min_stock'] as num?)?.toDouble(),
      location: json['location']?.toString(),
      notes: json['notes']?.toString(),
      imageUrls: (json['image_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : DateTime.now(),
      syncStatus: json['sync_status']?.toString() ?? 'synced',
      searchTokens: json['search_tokens']?.toString(),
    );
  }

  // ============================================================
  // تحويل إلى JSON (عند الرفع إلى API)
  // ============================================================
  Map<String, dynamic> toJson() {
    return {
      'sku': sku,
      'barcode': barcode,
      'name': name,
      'description': description,
      'category': category,
      'unit': unit,
      'unit_price': unitPrice,
      'wholesale_price': wholesalePrice,
      'stock_quantity': stockQuantity,
      'min_stock': minStock,
      'location': location,
      'notes': notes,
      'image_urls': imageUrls,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus,
      'search_tokens': searchTokens,
    };
  }

  // ============================================================
  // دالة لتطبيع النص (للبحث)
  // ============================================================
  static String normalize(String input) {
    if (input.isEmpty) return '';
    return input
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp('[أإآ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
        .toLowerCase()
        .trim();
  }

  // ============================================================
  // توليد رموز البحث (يُستدعى عند إنشاء المنتج أو تحديثه)
  // ============================================================
  static String generateSearchTokens(Product product) {
    final fields = [
      product.name,
      product.sku,
      product.barcode,
      product.category,
      product.description,
      product.unit,
      product.location,
      product.notes,
    ]
        .where((e) => e != null && e.isNotEmpty)
        .join(' ');
    return normalize(fields);
  }

  // ============================================================
  // إنشاء منتج جديد مع توليد رموز البحث تلقائياً
  // ============================================================
  factory Product.create({
    required String sku,
    String? barcode,
    required String name,
    String? description,
    String? category,
    String? unit,
    required double unitPrice,
    double? wholesalePrice,
    required double stockQuantity,
    double? minStock,
    String? location,
    String? notes,
    List<String>? imageUrls,
  }) {
    final now = DateTime.now();
    final product = Product(
      sku: sku,
      barcode: barcode,
      name: name,
      description: description,
      category: category,
      unit: unit,
      unitPrice: unitPrice,
      wholesalePrice: wholesalePrice,
      stockQuantity: stockQuantity,
      minStock: minStock,
      location: location,
      notes: notes,
      imageUrls: imageUrls ?? [],
      createdAt: now,
      updatedAt: now,
    );
    final tokens = generateSearchTokens(product);
    return product.copyWith(searchTokens: tokens);
  }

  // ============================================================
  // تحديث المنتج مع إعادة توليد رموز البحث
  // ============================================================
  Product update({
    String? barcode,
    String? name,
    String? description,
    String? category,
    String? unit,
    double? unitPrice,
    double? wholesalePrice,
    double? stockQuantity,
    double? minStock,
    String? location,
    String? notes,
    List<String>? imageUrls,
  }) {
    final updated = copyWith(
      barcode: barcode,
      name: name,
      description: description,
      category: category,
      unit: unit,
      unitPrice: unitPrice,
      wholesalePrice: wholesalePrice,
      stockQuantity: stockQuantity,
      minStock: minStock,
      location: location,
      notes: notes,
      imageUrls: imageUrls,
      updatedAt: DateTime.now(),
    );
    final newTokens = generateSearchTokens(updated);
    return updated.copyWith(searchTokens: newTokens);
  }

  // ============================================================
  // دالة مساعدة لمعرفة إذا كان المنتج بحاجة للمزامنة
  // ============================================================
  bool needsSync() => syncStatus != 'synced';

  // ============================================================
  // دالة لمعرفة إذا كان المخزون منخفضاً
  // ============================================================
  bool isLowStock() => minStock != null && stockQuantity <= minStock!;

  // ============================================================
  // تجاوز دالة toString لعرض ملخص المنتج
  // ============================================================
  @override
  String toString() {
    return 'Product(sku: $sku, name: $name, price: $unitPrice, stock: $stockQuantity)';
  }

  // ============================================================
  // مقارنة المنتجات (حسب SKU فقط)
  // ============================================================
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product && other.sku == sku;
  }

  @override
  int get hashCode => sku.hashCode;
}
