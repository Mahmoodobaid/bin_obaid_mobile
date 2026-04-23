import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../models/product_model.dart';
import '../../../../models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class CartItem {
  final Product product;
  int quantity;
  double? customDiscount;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.customDiscount,
  });

  double get effectivePrice {
    double basePrice = product.unitPrice;
    if (customDiscount != null && customDiscount! > 0) {
      return basePrice * (1 - customDiscount! / 100);
    }
    return basePrice;
  }

  double get totalPrice => effectivePrice * quantity;

  Map<String, dynamic> toJson() => {
        'sku': product.sku,
        'quantity': quantity,
        'customDiscount': customDiscount,
      };

  factory CartItem.fromJson(Map<String, dynamic> json, Product product) {
    return CartItem(
      product: product,
      quantity: json['quantity'] ?? 1,
      customDiscount: json['customDiscount']?.toDouble(),
    );
  }
}

class CartState {
  final List<CartItem> items;
  final String? couponCode;
  final double couponDiscountPercent;
  final bool isLoading;

  CartState({
    this.items = const [],
    this.couponCode,
    this.couponDiscountPercent = 0.0,
    this.isLoading = false,
  });

  int get uniqueItemsCount => items.length;
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);
  double get subtotal => items.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get couponDiscountValue => subtotal * (couponDiscountPercent / 100);
  double get total => subtotal - couponDiscountValue;
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  CartState copyWith({
    List<CartItem>? items,
    String? couponCode,
    double? couponDiscountPercent,
    bool? isLoading,
  }) {
    return CartState(
      items: items ?? this.items,
      couponCode: couponCode ?? this.couponCode,
      couponDiscountPercent: couponDiscountPercent ?? this.couponDiscountPercent,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

const String _cartBoxName = 'cart_box';
const String _cartKey = 'cart_data';
const String _couponKey = 'coupon_data';

class CartNotifier extends StateNotifier<CartState> {
  late final Box _cartBox;
  final Ref _ref;

  CartNotifier(this._ref) : super(CartState()) {
    _loadCartFromStorage();
  }

  Future<void> _loadCartFromStorage() async {
    try {
      state = state.copyWith(isLoading: true);
      _cartBox = await Hive.openBox(_cartBoxName);
      final cartData = _cartBox.get(_cartKey);
      final couponData = _cartBox.get(_couponKey);

      if (cartData != null && cartData is List) {
        final items = <CartItem>[];
        for (var itemJson in cartData) {
          final sku = itemJson['sku'];
          final productBox = await Hive.openBox<Product>('products');
          final product = productBox.get(sku);
          if (product != null) {
            items.add(CartItem.fromJson(itemJson, product));
          }
        }
        state = state.copyWith(items: items);
      }

      if (couponData != null && couponData is Map) {
        state = state.copyWith(
          couponCode: couponData['code'],
          couponDiscountPercent: (couponData['discount'] ?? 0).toDouble(),
        );
      }
    } catch (e) {
      debugPrint('خطأ في تحميل السلة: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _saveCartToStorage() async {
    try {
      final cartData = state.items.map((item) => item.toJson()).toList();
      await _cartBox.put(_cartKey, cartData);
      await _cartBox.put(_couponKey, {
        'code': state.couponCode,
        'discount': state.couponDiscountPercent,
      });
    } catch (e) {
      debugPrint('خطأ في حفظ السلة: $e');
    }
  }

  void addItem(Product product, {int quantity = 1, double? customDiscount}) {
    final existingIndex = state.items.indexWhere((item) => item.product.sku == product.sku);
    final newItems = List<CartItem>.from(state.items);

    if (existingIndex != -1) {
      final item = newItems[existingIndex];
      newItems[existingIndex] = CartItem(
        product: item.product,
        quantity: item.quantity + quantity,
        customDiscount: customDiscount ?? item.customDiscount,
      );
    } else {
      newItems.add(CartItem(
        product: product,
        quantity: quantity,
        customDiscount: customDiscount,
      ));
    }
    state = state.copyWith(items: newItems);
    _saveCartToStorage();
  }

  void removeItem(String sku) {
    final newItems = state.items.where((item) => item.product.sku != sku).toList();
    state = state.copyWith(items: newItems);
    _saveCartToStorage();
  }

  void incrementQuantity(String sku) {
    final newItems = state.items.map((item) {
      if (item.product.sku == sku) {
        return CartItem(
          product: item.product,
          quantity: item.quantity + 1,
          customDiscount: item.customDiscount,
        );
      }
      return item;
    }).toList();
    state = state.copyWith(items: newItems);
    _saveCartToStorage();
  }

  void decrementQuantity(String sku) {
    final newItems = state.items.map((item) {
      if (item.product.sku == sku && item.quantity > 1) {
        return CartItem(
          product: item.product,
          quantity: item.quantity - 1,
          customDiscount: item.customDiscount,
        );
      }
      return item;
    }).toList();
    state = state.copyWith(items: newItems);
    _saveCartToStorage();
  }

  void setQuantity(String sku, int newQuantity) {
    if (newQuantity < 1) return;
    final newItems = state.items.map((item) {
      if (item.product.sku == sku) {
        return CartItem(
          product: item.product,
          quantity: newQuantity,
          customDiscount: item.customDiscount,
        );
      }
      return item;
    }).toList();
    state = state.copyWith(items: newItems);
    _saveCartToStorage();
  }

  void updateCustomDiscount(String sku, double? discountPercent) {
    final newItems = state.items.map((item) {
      if (item.product.sku == sku) {
        return CartItem(
          product: item.product,
          quantity: item.quantity,
          customDiscount: discountPercent,
        );
      }
      return item;
    }).toList();
    state = state.copyWith(items: newItems);
    _saveCartToStorage();
  }

  void clearCart() {
    state = state.copyWith(items: [], couponCode: null, couponDiscountPercent: 0.0);
    _saveCartToStorage();
  }

  Future<bool> applyCoupon(String code) async {
    if (code.trim().toUpperCase() == 'SAVE10') {
      state = state.copyWith(couponCode: code.toUpperCase(), couponDiscountPercent: 10.0);
      _saveCartToStorage();
      return true;
    } else if (code.trim().toUpperCase() == 'WELCOME20') {
      state = state.copyWith(couponCode: code.toUpperCase(), couponDiscountPercent: 20.0);
      _saveCartToStorage();
      return true;
    }
    return false;
  }

  void removeCoupon() {
    state = state.copyWith(couponCode: null, couponDiscountPercent: 0.0);
    _saveCartToStorage();
  }

  void refreshPrices() {
    final newItems = state.items.map((item) {
      return CartItem(
        product: item.product,
        quantity: item.quantity,
        customDiscount: item.customDiscount,
      );
    }).toList();
    state = state.copyWith(items: newItems);
    _saveCartToStorage();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier(ref);
});

extension CartStateExtension on CartState {
  CartItem? getItemBySku(String sku) {
    try {
      return items.firstWhere((item) => item.product.sku == sku);
    } catch (_) {
      return null;
    }
  }

  bool containsSku(String sku) => items.any((item) => item.product.sku == sku);

  int quantityOf(String sku) {
    final item = getItemBySku(sku);
    return item?.quantity ?? 0;
  }
}
