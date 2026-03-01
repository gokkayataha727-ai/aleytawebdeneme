class TableModel {
  String id;
  String name;
  String originalName;
  bool isMerged;
  int sequenceNumber;
  double totalAmount; // YENİ: Toplam tutarı tutacak değişken
  List<SavedTable> mergedChildren;

  TableModel({
    required this.id, 
    required this.name, 
    required this.sequenceNumber,
    this.totalAmount = 0.0, // Varsayılan 0 TL
    this.isMerged = false,
    List<SavedTable>? mergedChildren,
  }) : originalName = name, 
       mergedChildren = mergedChildren ?? [];
}

class SavedTable {
  final TableModel table;
  final int originalIndex; 

  SavedTable({required this.table, required this.originalIndex});
}

class Section {
  String title;
  List<TableModel> tables;
  // Dolu masaları (tutarı 0'dan büyük olanları) sayar
  int get activeTableCount => tables.where((t) => t.totalAmount > 0).length;

  Section({
    required this.title,
    required this.tables,
  });
}

// Varsayılan Veriler
List<Section> sections = [
  Section(
    title: "Bahçe",
    tables: List.generate(25, (index) => TableModel(
      id: "b_$index", name: "Masa ${index + 1}", sequenceNumber: index
    )),
  ),
  Section(
    title: "Salon",
    tables: List.generate(25, (index) => TableModel(
      id: "s_$index", name: "Masa ${index + 1}", sequenceNumber: index
    )),
  ),
  Section(
    title: "Misafir",
    tables: List.generate(10, (index) => TableModel(
      id: "m_$index", name: "Masa ${index + 1}", sequenceNumber: index
    )),
  ),
  Section(
    title: "Giriş",
    tables: List.generate(10, (index) => TableModel(
      id: "g_$index", name: "Masa ${index + 1}", sequenceNumber: index
    )),
  ),
];