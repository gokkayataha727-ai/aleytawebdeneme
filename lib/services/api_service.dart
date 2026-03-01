import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/order_model.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String _baseUrl = 'http://192.168.1.77:8080/api';

  // ============ KATEGORİLER ============

  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await http.get(Uri.parse('$_baseUrl/categories'));
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  Future<int> addCategory(String name, String type, {String color = 'orange'}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/categories'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'type': type, 'color': color}),
    );
    final data = jsonDecode(response.body);
    return data['id'] as int;
  }

  Future<void> updateCategory(int id, String name, String type, {String color = 'orange'}) async {
    await http.put(
      Uri.parse('$_baseUrl/categories/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'type': type, 'color': color}),
    );
  }

  Future<void> deleteCategory(int id) async {
    await http.delete(Uri.parse('$_baseUrl/categories/$id'));
  }

  // ============ ÜRÜNLER ============

  Future<int> addProduct(int categoryId, String name, double price) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/products'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'category_id': categoryId, 'name': name, 'price': price}),
    );
    final data = jsonDecode(response.body);
    return data['id'] as int;
  }

  Future<void> updateProduct(int id, String name, double price) async {
    await http.put(
      Uri.parse('$_baseUrl/products/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'price': price}),
    );
  }

  Future<void> deleteProduct(int id) async {
    await http.delete(Uri.parse('$_baseUrl/products/$id'));
  }

  // ============ SİPARİŞLER ============

  Future<int> createOrder(OrderModel order) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/orders'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'table_name': order.tableName,
        'section_name': order.sectionName,
        'status': order.status,
        'is_extra': order.isExtra,
        'total_amount': order.totalAmount,
        'items': order.items.map((item) => {
          'product_name': item.productName,
          'category_name': item.categoryName,
          'price': item.price,
          'quantity': item.quantity,
        }).toList(),
      }),
    );
    final data = jsonDecode(response.body);
    return data['id'] as int;
  }

  Future<List<OrderModel>> getActiveOrders({required bool isExtra}) async {
    final response = await http.get(Uri.parse('$_baseUrl/orders/active?is_extra=$isExtra'));
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((map) {
      final order = OrderModel.fromMap(Map<String, dynamic>.from(map));
      order.id = map['id'] as int;
      if (map['items'] != null) {
        order.items = (map['items'] as List).map((i) => OrderItemModel.fromMap(Map<String, dynamic>.from(i))).toList();
      }
      return order;
    }).toList();
  }

  Future<void> updateOrderStatus(int orderId, String status, {String? paymentType, String? cancelReason}) async {
    await http.put(
      Uri.parse('$_baseUrl/orders/$orderId/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status, if (paymentType != null) 'payment_type': paymentType, if (cancelReason != null) 'cancel_reason': cancelReason}),
    );
  }

  Future<void> payOrdersByTable(String tableName, String sectionName, String paymentType) async {
    await http.put(
      Uri.parse('$_baseUrl/orders/table/pay'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'table_name': tableName, 'section_name': sectionName, 'payment_type': paymentType}),
    );
  }

  Future<void> cancelOrdersByTable(String tableName, String sectionName, String reason) async {
    await http.put(
      Uri.parse('$_baseUrl/orders/table/cancel'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'table_name': tableName, 'section_name': sectionName, 'cancel_reason': reason}),
    );
  }

  Future<List<OrderModel>> getOrderHistory() async {
    final response = await http.get(Uri.parse('$_baseUrl/orders/history'));
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((map) {
      final order = OrderModel.fromMap(Map<String, dynamic>.from(map));
      order.id = map['id'] as int;
      return order;
    }).toList();
  }

  // ============ RAPORLAR ============

  Future<int> getTodayPaidCount() async {
    final response = await http.get(Uri.parse('$_baseUrl/reports/daily'));
    final data = jsonDecode(response.body);
    return data['paid_count'] as int;
  }

  Future<int> getActiveOrderCount() async {
    final response = await http.get(Uri.parse('$_baseUrl/reports/daily'));
    final data = jsonDecode(response.body);
    return data['active_count'] as int;
  }

  Future<Map<int, int>> getHourlyPayments() async {
    final response = await http.get(Uri.parse('$_baseUrl/reports/hourly'));
    final Map<String, dynamic> data = jsonDecode(response.body);
    return data.map((key, value) => MapEntry(int.parse(key), value as int));
  }

  Future<Map<String, int>> getPaymentTypeDistribution() async {
    final response = await http.get(Uri.parse('$_baseUrl/reports/payment-types'));
    final Map<String, dynamic> data = jsonDecode(response.body);
    return data.map((key, value) => MapEntry(key, value as int));
  }

  Future<Map<String, int>> getStatusDistribution() async {
    final response = await http.get(Uri.parse('$_baseUrl/reports/status-distribution'));
    final Map<String, dynamic> data = jsonDecode(response.body);
    return data.map((key, value) => MapEntry(key, value as int));
  }

  Future<Map<String, dynamic>> getRevenueReport() async {
    final response = await http.get(Uri.parse('$_baseUrl/reports/revenue'));
    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  Future<Map<String, dynamic>> getDiscountsReport() async {
    final response = await http.get(Uri.parse('$_baseUrl/reports/discounts'));
    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  // ============ FİŞLER ============

  Future<List<Map<String, dynamic>>> getReceiptsByTable() async {
    final response = await http.get(Uri.parse('$_baseUrl/receipts'));
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((m) => Map<String, dynamic>.from(m)).toList();
  }
}
