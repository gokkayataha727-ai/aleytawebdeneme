import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';

class OrdersScreen extends StatefulWidget {
  final int initialTab; // 0: Mutfak, 1: Ekstralar
  const OrdersScreen({super.key, this.initialTab = 0});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();

  List<OrderModel> _kitchenOrders = [];
  List<OrderModel> _extraOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      _kitchenOrders = await _api.getActiveOrders(isExtra: false);
      _extraOrders = await _api.getActiveOrders(isExtra: true);
    } catch (e) {
      _showSnack('Siparişler yüklenirken hata: $e');
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: const Text('Siparişler', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.red,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.red,
          tabs: [
            Tab(text: 'Mutfak (${_kitchenOrders.length})'),
            Tab(text: 'Ekstralar (${_extraOrders.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOrderList(_kitchenOrders),
                _buildOrderList(_extraOrders),
              ],
            ),
    );
  }

  Widget _buildOrderList(List<OrderModel> orders) {
    if (orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('Aktif sipariş yok', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive: geniş ekranda grid, dar ekranda liste
          if (constraints.maxWidth > 800) {
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: constraints.maxWidth > 1200 ? 450 : 500,
                childAspectRatio: 2.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: orders.length,
              itemBuilder: (context, index) => _buildOrderCard(orders[index]),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) => _buildOrderCard(orders[index]),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final dateFormat = DateFormat('dd.MM.yyyy\nHH:mm');

    Color statusColor;
    Color statusBgColor;
    switch (order.status) {
      case 'hazirlaniyor':
        statusColor = const Color(0xFFB71C1C);
        statusBgColor = const Color(0xFFFFCDD2);
        break;
      case 'hazir':
        statusColor = const Color(0xFF2E7D32);
        statusBgColor = const Color(0xFFC8E6C9);
        break;
      case 'siparis_alindi':
        statusColor = const Color(0xFFE65100);
        statusBgColor = const Color(0xFFFFE0B2);
        break;
      default:
        statusColor = Colors.grey;
        statusBgColor = Colors.grey.shade200;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sol taraf: Durum + İkon + Tarih
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    order.statusText,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB71C1C).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.restaurant, color: Color(0xFFB71C1C), size: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  dateFormat.format(order.createdAt),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Container(width: 1, height: 100, color: Colors.grey.shade300),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.tableName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(order.sectionName.toUpperCase(), style: TextStyle(fontSize: 13, color: Colors.grey.shade600, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Text('₺${order.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
            ),
            Column(
              children: [
                const SizedBox(height: 60),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, color: Colors.grey, size: 28),
                  onSelected: (value) => _handleOrderAction(order, value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'yazdir', child: Row(children: [Icon(Icons.print, color: Colors.black54), SizedBox(width: 8), Text('Yazdır')])),
                    const PopupMenuItem(value: 'ode', child: Row(children: [Icon(Icons.payment, color: Colors.green), SizedBox(width: 8), Text('Öde')])),
                    const PopupMenuItem(value: 'iptal', child: Row(children: [Icon(Icons.cancel, color: Colors.red), SizedBox(width: 8), Text('İptal Et')])),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleOrderAction(OrderModel order, String action) {
    switch (action) {
      case 'yazdir':
        _showSnack('${order.tableName} fişi yazdırılıyor...');
        break;
      case 'ode':
        _showPaymentDialog(order);
        break;
      case 'iptal':
        _showCancelDialog(order);
        break;
    }
  }

  void _showPaymentDialog(OrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${order.tableName} Ödeme: ₺${order.totalAmount.toStringAsFixed(2)}'),
        content: const Text('Ödeme tipini seçin:'),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.money),
            label: const Text('NAKİT'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _api.updateOrderStatus(order.id!, 'odendi', paymentType: 'Nakit');
              _showSnack('${order.tableName} Nakit ödemesi alındı.');
              _loadOrders();
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.credit_card),
            label: const Text('KART'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _api.updateOrderStatus(order.id!, 'odendi', paymentType: 'Kredi Kartı');
              _showSnack('${order.tableName} Kart ödemesi alındı.');
              _loadOrders();
            },
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(OrderModel order) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${order.tableName} İptal Nedeni'),
        content: TextField(
          controller: reasonController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Lütfen iptal nedenini giriniz', border: OutlineInputBorder()),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                _showSnack('Lütfen bir iptal nedeni girin!');
                return;
              }
              Navigator.pop(ctx);
              await _api.updateOrderStatus(order.id!, 'iptal', cancelReason: reasonController.text.trim());
              _showSnack('${order.tableName} siparişi iptal edildi.');
              _loadOrders();
            },
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }
}
