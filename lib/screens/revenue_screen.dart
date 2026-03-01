import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  double _todayRevenue = 0;
  double _totalRevenue = 0;
  int _todayOrderCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.getRevenueReport();
      _todayRevenue = (data['today_revenue'] as num).toDouble();
      _totalRevenue = (data['total_revenue'] as num).toDouble();
      _todayOrderCount = data['today_order_count'] as int;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 1,
        title: const Text('Ciro', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Responsive: yan yana veya alt alta
                      if (screenWidth > 600)
                        Row(
                          children: [
                            Expanded(child: _buildCard('Bugünkü Ciro', '₺${_todayRevenue.toStringAsFixed(2)}', Icons.today, Colors.green)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildCard('Toplam Ciro', '₺${_totalRevenue.toStringAsFixed(2)}', Icons.trending_up, Colors.blue)),
                          ],
                        )
                      else ...[
                        _buildCard('Bugünkü Ciro', '₺${_todayRevenue.toStringAsFixed(2)}', Icons.today, Colors.green),
                        const SizedBox(height: 16),
                        _buildCard('Toplam Ciro', '₺${_totalRevenue.toStringAsFixed(2)}', Icons.trending_up, Colors.blue),
                      ],
                      const SizedBox(height: 16),
                      _buildCard('Bugün Tamamlanan Sipariş', '$_todayOrderCount', Icons.check_circle, Colors.orange),
                      if (_todayOrderCount > 0) ...[
                        const SizedBox(height: 16),
                        _buildCard('Ortalama Sipariş Tutarı',
                          '₺${(_todayRevenue / _todayOrderCount).toStringAsFixed(2)}',
                          Icons.analytics, Colors.purple),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 16),
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 6),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
