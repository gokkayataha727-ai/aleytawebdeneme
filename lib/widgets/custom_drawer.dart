import 'package:flutter/material.dart';
import '../screens/orders_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/receipts_screen.dart';
import '../screens/order_history_screen.dart';
import '../screens/discounts_screen.dart';
import '../screens/revenue_screen.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFF8D7DA),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.redAccent),
            child: Center(
              child: Text(
                'Adisyon Sistemi',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Anasayfa'),
            onTap: () => Navigator.pop(context),
          ),
          // Siparişler
          ExpansionTile(
            leading: const Icon(Icons.restaurant_menu),
            title: const Text('Siparişler'),
            children: [
              ListTile(
                title: const Text('   Mutfak'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen(initialTab: 0)));
                },
              ),
              ListTile(
                title: const Text('   Ekstralar'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen(initialTab: 1)));
                },
              ),
            ],
          ),
          // Raporlar
          ExpansionTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Raporlar'),
            children: [
              ListTile(
                title: const Text('   Günlük Bilgiler'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
                },
              ),
              ListTile(
                title: const Text('   İndirimler'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscountsScreen()));
                },
              ),
              ListTile(
                title: const Text('   Ciro'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RevenueScreen()));
                },
              ),
              ListTile(
                title: const Text('   Fişler'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceiptsScreen()));
                },
              ),
              ListTile(
                title: const Text('   Sipariş Geçmişi'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderHistoryScreen()));
                },
              ),
            ],
          ),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings),
            title: const Text('Yetkilendirme'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.print),
            title: const Text('Yazıcı Tanımlama'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}