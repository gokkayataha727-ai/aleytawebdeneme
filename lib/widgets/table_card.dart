import 'package:flutter/material.dart';
import '../models/section_model.dart';

class TableCard extends StatelessWidget {
  final TableModel table;
  final Function(String type) onPayment;
  final Function(String reason) onCancel; // DÜZELTME: Artık iptal nedeni (String) gönderiyor
  final VoidCallback onMove;
  final VoidCallback onMerge;
  final VoidCallback onUnmerge;
  final VoidCallback onTransfer;
  final VoidCallback onPrint;
  final VoidCallback? onTap;

  const TableCard({
    super.key,
    required this.table,
    required this.onPayment,
    required this.onCancel,
    required this.onMove,
    required this.onMerge,
    required this.onUnmerge,
    required this.onTransfer,
    required this.onPrint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool isActive = table.totalAmount > 0;

    return Card(
      color: table.isMerged 
          ? Colors.orange.shade300 
          : (isActive ? Colors.red.shade400 : Colors.redAccent.shade100),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      table.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                    if (isActive) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${table.totalAmount.toStringAsFixed(2)} ₺",
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
            
            Positioned(
              top: 0,
              right: 0,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) => _handleMenu(context, value),
                itemBuilder: (context) {
                  bool isMerged = table.isMerged;
                  return [
                    const PopupMenuItem(value: 'odeme', child: Row(children: [Icon(Icons.payment, color: Colors.green), SizedBox(width: 8), Text("Ödeme Al")])),
                    const PopupMenuItem(value: 'iptal', child: Row(children: [Icon(Icons.cancel, color: Colors.red), SizedBox(width: 8), Text("İptal")])),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'degistir', child: Row(children: [Icon(Icons.swap_horiz, color: Colors.blue), SizedBox(width: 8), Text("Masayı Değiştir")])),
                    PopupMenuItem(
                      value: isMerged ? 'ayir' : 'birlestir',
                      child: Row(children: [
                        Icon(isMerged ? Icons.call_split : Icons.merge_type, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(isMerged ? "Masaları Ayır" : "Masaları Birleştir")
                      ]),
                    ),
                    const PopupMenuItem(value: 'aktar', child: Row(children: [Icon(Icons.import_export, color: Colors.purple), SizedBox(width: 8), Text("Adisyon Aktar")])),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'yazdir', child: Row(children: [Icon(Icons.print, color: Colors.black54), SizedBox(width: 8), Text("Yazdır")])),
                  ];
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenu(BuildContext context, String value) {
    switch (value) {
      case 'odeme':
        // BOŞ MASA KONTROLÜ
        if (table.totalAmount <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ödeme alınacak sipariş yok!")));
          return;
        }
        _showPaymentDialog(context);
        break;
      case 'iptal':
        // BOŞ MASA KONTROLÜ
        if (table.totalAmount <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İptal edilecek sipariş yok!")));
          return;
        }
        _showCancelReasonDialog(context); // İptal nedeni penceresini aç
        break;
      case 'degistir':
        onMove();
        break;
      case 'birlestir':
        onMerge();
        break;
      case 'ayir':
        onUnmerge();
        break;
      case 'aktar':
        onTransfer();
        break;
      case 'yazdir':
        onPrint();
        break;
    }
  }

  // --- İPTAL NEDENİ PENCERESİ (YENİ) ---
  void _showCancelReasonDialog(BuildContext context) {
    TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("${table.name} İptal Nedeni"),
        content: TextField(
          controller: reasonController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Lütfen iptal nedenini giriniz (Örn: Müşteri vazgeçti)",
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Vazgeç"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir iptal nedeni girin!")));
                return;
              }
              Navigator.pop(ctx);
              onCancel(reasonController.text.trim()); // Nedeni anasayfaya gönder
            },
            child: const Text("İptal Et"),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("${table.name} Ödeme: ${table.totalAmount.toStringAsFixed(2)} ₺"),
        content: const Text("Ödeme alındıktan sonra masa sıfırlanacaktır."),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.money),
            label: const Text("NAKİT"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              onPayment('Nakit');
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.credit_card),
            label: const Text("KART"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              onPayment('Kredi Kartı');
            },
          ),
        ],
      ),
    );
  }
}