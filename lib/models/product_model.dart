import 'package:hive/hive.dart';



@HiveType(typeId: 0)
class Product {
  @HiveField(0) final String sku;
  @HiveField(1) final String? barcode;
  @HiveField(2) final String name;
  @HiveField(3) final String? description;
  @HiveField(4) final String? category;
  @HiveField(5) final String? unit;
  @HiveField(6) final double unitPrice;
  @HiveField(7) final double? wholesalePrice;
  @HiveField(8) final double stockQuantity;
  @HiveField(9) final double? minStock;
  @HiveField(10) final String? location;
  @HiveField(11) final String? notes;
  @HiveField(12) final List<String> imageUrls;
  @HiveField(13) final DateTime createdAt;
  @HiveField(14) DateTime updatedAt;
  @HiveField(15) String syncStatus;
  @HiveField(16) final String? searchTokens;

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

  Product copyWith({
    String? sku, String? barcode, String? name, String? description,
    String? category, String? unit, double? unitPrice, double? wholesalePrice,
    double? stockQuantity, double? minStock, String? location, String? notes,
    List<String>? imageUrls, DateTime? createdAt, DateTime? updatedAt,
    String? syncStatus, String? searchTokens,
  }) {
    return Product(
      sku: sku ?? this.sku, barcode: barcode ?? this.barcode,
      name: name ?? this.name, description: description ?? this.description,
      category: category ?? this.category, unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice, wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      stockQuantity: stockQuantity ?? this.stockQuantity, minStock: minStock ?? this.minStock,
      location: location ?? this.location, notes: notes ?? this.notes,
      imageUrls: imageUrls ?? List.from(this.imageUrls),
      createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus, searchTokens: searchTokens ?? this.searchTokens,
    );
  }

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
      imageUrls: (json['image_urls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'].toString()) : DateTime.now(),
      syncStatus: json['sync_status']?.toString() ?? 'synced',
      searchTokens: json['search_tokens']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'sku': sku, 'barcode': barcode, 'name': name, 'description': description,
    'category': category, 'unit': unit, 'unit_price': unitPrice,
    'wholesale_price': wholesalePrice, 'stock_quantity': stockQuantity,
    'min_stock': minStock, 'location': location, 'notes': notes,
    'image_urls': imageUrls, 'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(), 'sync_status': syncStatus,
    'search_tokens': searchTokens,
  };
}
