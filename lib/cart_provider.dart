import 'package:flutter/foundation.dart';
import 'menu_item.dart';

class CartProvider extends ChangeNotifier {
  final List<MenuItem> _cartItems = [];
  DateTime? _lastAddTime;
  String? _lastAddedItemName;

  List<MenuItem> get cartItems => _cartItems;

  void addToCart(MenuItem item) {
    final now = DateTime.now();
    if (_lastAddTime != null &&
        _lastAddedItemName == item.name &&
        now.difference(_lastAddTime!).inSeconds < 2) {
      debugPrint('Duplicate add prevented for: ${item.name}');
      return;
    }

    _cartItems.add(item);
    _lastAddTime = now;
    _lastAddedItemName = item.name;
    notifyListeners();
  }

  void removeFromCart(MenuItem item) {
    _cartItems.remove(item);
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    _lastAddTime = null;
    _lastAddedItemName = null;
    notifyListeners();
  }
}
