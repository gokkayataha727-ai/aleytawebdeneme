class OrderItemModel {
  int? id;
  int? orderId;
  String productName;
  String categoryName;
  double price;
  int quantity;

  OrderItemModel({
    this.id,
    this.orderId,
    required this.productName,
    required this.categoryName,
    required this.price,
    required this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'product_name': productName,
      'category_name': categoryName,
      'price': price,
      'quantity': quantity,
    };
  }

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      id: map['id'] as int?,
      orderId: map['order_id'] as int?,
      productName: map['product_name'] as String,
      categoryName: map['category_name'] as String,
      price: (map['price'] as num).toDouble(),
      quantity: map['quantity'] as int,
    );
  }
}

class OrderModel {
  int? id;
  String tableName;
  String sectionName;
  String status; // siparis_alindi, hazirlaniyor, hazir, odendi, iptal
  bool isExtra;
  double totalAmount;
  String? paymentType;
  String? cancelReason;
  DateTime createdAt;
  DateTime? paidAt;
  DateTime? cancelledAt;
  List<OrderItemModel> items;

  OrderModel({
    this.id,
    required this.tableName,
    required this.sectionName,
    this.status = 'siparis_alindi',
    this.isExtra = false,
    required this.totalAmount,
    this.paymentType,
    this.cancelReason,
    DateTime? createdAt,
    this.paidAt,
    this.cancelledAt,
    List<OrderItemModel>? items,
  })  : createdAt = createdAt ?? DateTime.now(),
        items = items ?? [];

  String get statusText {
    switch (status) {
      case 'siparis_alindi':
        return 'Sipariş Alındı';
      case 'hazirlaniyor':
        return 'Hazırlanıyor';
      case 'hazir':
        return 'Hazır';
      case 'odendi':
        return 'Ödendi';
      case 'iptal':
        return 'İptal';
      default:
        return status;
    }
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: map['id'] as int?,
      tableName: map['table_name'] as String,
      sectionName: map['section_name'] as String,
      status: map['status'] as String? ?? 'siparis_alindi',
      isExtra: map['is_extra'] as bool? ?? false,
      totalAmount: (map['total_amount'] as num).toDouble(),
      paymentType: map['payment_type'] as String?,
      cancelReason: map['cancel_reason'] as String?,
      createdAt: map['created_at'] is DateTime
          ? map['created_at'] as DateTime
          : DateTime.parse(map['created_at'].toString()),
      paidAt: map['paid_at'] != null
          ? (map['paid_at'] is DateTime
              ? map['paid_at'] as DateTime
              : DateTime.parse(map['paid_at'].toString()))
          : null,
      cancelledAt: map['cancelled_at'] != null
          ? (map['cancelled_at'] is DateTime
              ? map['cancelled_at'] as DateTime
              : DateTime.parse(map['cancelled_at'].toString()))
          : null,
    );
  }
}
