import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/product_model.dart';

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier());

class CartItem {
  final Product product;
  int quantity;
  CartItem({required this.product, this.quantity = 1});
}

class CartState {
  final List<CartItem> items;
  CartState({this.items = const []});

  double get totalAmount => items.fold(0, (sum, item) => sum + (item.product.unitPrice * item.quantity));

  CartState copyWith({List<CartItem>? items}) => CartState(items: items ?? this.items);
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(CartState());

  void addItem(Product product) {
    final existingIndex = state.items.indexWhere((item) => item.product.sku == product.sku);
    List<CartItem> newItems;
    if (existingIndex != -1) {
      newItems = [...state.items];
      newItems[existingIndex] = CartItem(product: product, quantity: newItems[existingIndex].quantity + 1);
    } else {
      newItems = [...state.items, CartItem(product: product)];
    }
    state = state.copyWith(items: newItems);
  }

  void removeItem(String sku) {
    final newItems = state.items.where((item) => item.product.sku != sku).toList();
    state = state.copyWith(items: newItems);
  }

  void incrementQuantity(String sku) {
    final newItems = state.items.map((item) {
      if (item.product.sku == sku) return CartItem(product: item.product, quantity: item.quantity + 1);
      return item;
    }).toList();
    state = state.copyWith(items: newItems);
  }

  void decrementQuantity(String sku) {
    final newItems = state.items.map((item) {
      if (item.product.sku == sku) {
        final newQty = item.quantity - 1;
        return newQty > 0 ? CartItem(product: item.product, quantity: newQty) : null;
      }
      return item;
    }).whereType<CartItem>().toList();
    state = state.copyWith(items: newItems);
  }

  void clearCart() => state = CartState();
}
