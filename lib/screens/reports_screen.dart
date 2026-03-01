import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;

  int _paidCount = 0;
  int _activeCount = 0;
  Map<int, int> _hourlyPayments = {};
  Map<String, int> _paymentTypes = {};
  Map<String, int> _statusDist = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      _paidCount = await _api.getTodayPaidCount();
      _activeCount = await _api.getActiveOrderCount();
      _hourlyPayments = await _api.getHourlyPayments();
      _paymentTypes = await _api.getPaymentTypeDistribution();
      _statusDist = await _api.getStatusDistribution();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Raporlar yüklenirken hata: $e')));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: const Text('Günlük Bilgiler', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStats)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Üst kartlar
                        Row(
                          children: [
                            Expanded(child: _buildStatCard('Alınan Ödemeler', '$_paidCount', Icons.payment, Colors.green)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildStatCard('Açık Siparişler', '$_activeCount', Icons.restaurant, Colors.orange)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Responsive: geniş ekranda yan yana
                        if (screenWidth > 800)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                _buildSectionTitle('Alınan Ödemeler (Saat Bazlı)'),
                                const SizedBox(height: 8),
                                _buildHourlyChart(),
                              ])),
                              const SizedBox(width: 16),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                _buildSectionTitle('Ödeme Tipleri'),
                                const SizedBox(height: 8),
                                _buildPaymentTypePieChart(),
                              ])),
                            ],
                          )
                        else ...[
                          _buildSectionTitle('Alınan Ödemeler (Saat Bazlı)'),
                          const SizedBox(height: 8),
                          _buildHourlyChart(),
                          const SizedBox(height: 24),
                          _buildSectionTitle('Ödeme Tipleri'),
                          const SizedBox(height: 8),
                          _buildPaymentTypePieChart(),
                        ],
                        const SizedBox(height: 24),
                        _buildSectionTitle('Sipariş Durumları'),
                        const SizedBox(height: 8),
                        _buildStatusPieChart(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));

  Widget _buildHourlyChart() {
    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < 24; i++) {
      barGroups.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(toY: (_hourlyPayments[i] ?? 0).toDouble(), color: Colors.redAccent, width: 10, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
      ]));
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, gi, rod, ri) => BarTooltipItem('${group.x}:00\n${rod.toY.toInt()} sipariş', const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => v.toInt() % 3 == 0 ? Text('${v.toInt()}', style: const TextStyle(fontSize: 10)) : const Text(''))),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, m) => v == v.roundToDouble() ? Text('${v.toInt()}', style: const TextStyle(fontSize: 10)) : const Text(''))),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            barGroups: barGroups,
          )),
        ),
      ),
    );
  }

  Widget _buildPaymentTypePieChart() {
    if (_paymentTypes.isEmpty) return _buildEmptyChartCard('Bugün henüz ödeme alınmadı');
    final colors = [Colors.green, Colors.blue, Colors.orange, Colors.purple];
    int ci = 0;
    List<PieChartSectionData> sections = _paymentTypes.entries.map((e) {
      final c = colors[ci++ % colors.length];
      return PieChartSectionData(color: c, value: e.value.toDouble(), title: '${e.key}\n(${e.value})', radius: 60, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white));
    }).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: SizedBox(height: 200, child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 30, sectionsSpace: 3)))),
    );
  }

  Widget _buildStatusPieChart() {
    final labels = {'siparis_alindi': 'Sipariş Alındı', 'hazirlaniyor': 'Hazırlanıyor', 'hazir': 'Hazır', 'odendi': 'Ödendi', 'iptal': 'İptal'};
    final colors = {'siparis_alindi': Colors.orange, 'hazirlaniyor': Colors.red, 'hazir': Colors.green, 'odendi': Colors.blue, 'iptal': Colors.grey};

    if (_statusDist.isEmpty) return _buildEmptyChartCard('Henüz sipariş verisi yok');

    List<PieChartSectionData> sections = _statusDist.entries.map((e) => PieChartSectionData(
      color: colors[e.key] ?? Colors.grey, value: e.value.toDouble(),
      title: '${labels[e.key] ?? e.key}\n(${e.value})', radius: 60,
      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
    )).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          SizedBox(height: 200, child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 30, sectionsSpace: 3))),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 8, children: _statusDist.entries.map((e) => Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[e.key] ?? Colors.grey, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text('${labels[e.key] ?? e.key}: ${e.value}', style: const TextStyle(fontSize: 12)),
          ])).toList()),
        ]),
      ),
    );
  }

  Widget _buildEmptyChartCard(String msg) => Card(
    elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(msg, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)))),
  );
}
