// lib/services/expiry_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/expiry_product.dart';
import 'notification_service.dart';

class ExpiryService {
  static const String _storageKey = 'expiry_products';
  final NotificationService _notificationService = NotificationService();

  Future<List<ExpiryProduct>> getProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_storageKey);
    if (data == null) return [];
    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((e) => ExpiryProduct.fromJson(e)).toList();
  }

  // Novo: Verifica se há produtos precisando de notificação agora
  Future<void> checkAndNotify() async {
    final products = await getProducts();
    final now = DateTime.now();

    for (final product in products) {
      final scheduledDate = product.expiryDate.subtract(Duration(days: product.notifyDaysBefore));
      
      // Se a data de notificação é hoje ou já passou, e o produto ainda não venceu
      if (now.isAfter(scheduledDate) && now.isBefore(product.expiryDate.add(const Duration(days: 1)))) {
        await _scheduleNotification(product, now: true);
      } else {
        await _scheduleNotification(product);
      }
    }
  }

  Future<void> saveProduct(ExpiryProduct product) async {
    final products = await getProducts();
    final index = products.indexWhere((p) => p.id == product.id);
    
    ExpiryProduct productToSave = product;
    if (product.id.isEmpty) {
      productToSave = product.copyWith(id: const Uuid().v4());
      products.add(productToSave);
    } else if (index != -1) {
      products[index] = product;
    } else {
      products.add(product);
    }

    await _persist(products);
    await _scheduleNotification(productToSave);
  }

  Future<void> deleteProduct(String id) async {
    final products = await getProducts();
    products.removeWhere((p) => p.id == id);
    await _persist(products);
    await _notificationService.cancelNotification(id.hashCode);
  }

  Future<void> _persist(List<ExpiryProduct> products) async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(products.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, data);
  }

  Future<void> _scheduleNotification(ExpiryProduct product, {bool now = false}) async {
    DateTime notificationTime;
    
    if (now) {
      // Dispara em 5 segundos se for para notificar agora
      notificationTime = DateTime.now().add(const Duration(seconds: 5));
    } else {
      final scheduledDate = product.expiryDate.subtract(Duration(days: product.notifyDaysBefore));
      notificationTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        9, 0, 0
      );
    }

    if (notificationTime.isBefore(DateTime.now()) && !now) return;

    final String dateFormatted = "${product.expiryDate.day}/${product.expiryDate.month}/${product.expiryDate.year}";

    await _notificationService.scheduleNotification(
      id: product.id.hashCode,
      title: 'Atenção: Validade Próxima',
      body: 'O produto ${product.name} vence dia $dateFormatted.',
      scheduledDate: notificationTime,
    );
  }
}
