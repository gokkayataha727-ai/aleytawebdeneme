import 'package:flutter/material.dart';
import 'table_card.dart';

class TableGrid extends StatelessWidget {
  final int itemCount;
  final String sectionName; // Yeni parametre

  const TableGrid({
    super.key, 
    required this.itemCount, 
    this.sectionName = "Bölüm"
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180, 
          childAspectRatio: 3 / 2, 
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // TableCard'a bölüm ismini de gönderiyoruz
          return TableCard(tableNumber: index + 1, sectionName: sectionName);
        },
      ),
    );
  }
}