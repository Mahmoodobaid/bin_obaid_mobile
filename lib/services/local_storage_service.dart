import 'package:hive_flutter/hive_flutter.dart';
import '../models/product_model.dart';

class LocalStorageService {
  static const String _productsBox = 'products_box';
  static const String _metaBox = 'meta_box';

  static Future<void> init() async {
    await Hive.initFlutter();
  }

  static Future<void> saveProducts(List<Product> products) async {
    var box = await Hive.openBox(_productsBox);
    await box.clear();
    for (var p in products) {
      await box.put(p.sku, p.toJson());
    }
    var meta = await Hive.openBox(_metaBox);
    await meta.put('last_sync', DateTime.now().toIso8601String());
  }

  static Future<List<Product>> getProducts() async {
    var box = await Hive.openBox(_productsBox);
    return box.values.map((e) => Product.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<DateTime?> getLastSyncTime() async {
    var meta = await Hive.openBox(_metaBox);
    final t = meta.get('last_sync');
    return t != null ? DateTime.parse(t) : null;
  }
}
