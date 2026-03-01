import 'package:flutter/material.dart';

class PaymentScreen extends StatelessWidget {
  final String tableName;

  const PaymentScreen({super.key, required this.tableName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("$tableName - Ödeme Ekranı"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 100, color: Colors.green),
            const SizedBox(height: 20),
            Text(
              "$tableName için ödeme alınıyor...",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Veritabanı olunca buraya "Siparişi Kapat" kodu gelecek
                Navigator.pop(context); // Anasayfaya dön
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Ödeme Başarıyla Alındı ve Kaydedildi.")),
                );
              },
              child: const Text("İşlemi Tamamla"),
            )
          ],
        ),
      ),
    );
  }
}