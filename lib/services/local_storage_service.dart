import 'package:hive_flutter/hive_flutter.dart'; import '../models/product_model.dart';
class LocalStorageService {
  static Future<void> init() async => await Hive.initFlutter();
  static Future<void> saveProducts(List<Product> products) async { var box = await Hive.openBox('products'); await box.clear(); for(var p in products) await box.put(p.sku, p.toJson()); await (await Hive.openBox('meta')).put('last_sync', DateTime.now().toIso8601String()); }
  static Future<List<Product>> getProducts() async { var box = await Hive.openBox('products'); return box.values.map((e) => Product.fromJson(Map<String,dynamic>.from(e))).toList(); }
}
