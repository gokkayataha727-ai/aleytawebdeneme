import 'package:flutter/material.dart';
import '../models/section_model.dart';
import '../services/api_service.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/table_card.dart';
import 'menu_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Model dosyasındaki global listeyi kullanıyoruz
  List<Section> _currentSections = sections;
  final ApiService _api = ApiService();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      key: ValueKey(_currentSections.length),
      length: _currentSections.length,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFEBEE),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: const IconThemeData(color: Colors.green, size: 35),
          title: const Text('Adisyon', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        ),
        
        drawer: const CustomDrawer(),

        body: TabBarView(
          children: _currentSections.map((section) {
            return Stack(
              children: [
                // --- MASA IZGARASI ---
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180, 
                      childAspectRatio: 3 / 2, 
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: section.tables.length,
                    itemBuilder: (context, index) {
                      final table = section.tables[index];
                      // TableCard'a fonksiyonları gönderiyoruz
                      return TableCard(
                        table: table,

                        onTap: () async {
                          // 1. Menü ekranına git ve dönmesini bekle (await)
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MenuScreen(
                                tableName: table.name,
                                sectionName: section.title,
                                currentTotal: table.totalAmount,
                              ),
                            ),
                          );

                          // 2. Eğer bir tutar ile geri döndüyse masayı güncelle
                          if (result != null && result is double) {
                            setState(() {
                              table.totalAmount = result;
                            });
                          }
                        },
                        
                        onPayment: (type) => _handlePayment(section, table, type),
                        onCancel: (reason) => _handleCancel(section, table, reason),
                        onMove: () => _handleMoveTable(section, table),
                        onMerge: () => _handleMergeTable(section, table),
                        onUnmerge: () => _handleUnmergeTable(section, table),
                        
                        // --- DÜZELTİLEN KISIM (ADİSYON AKTAR) ---
                        onTransfer: () => _handleTransferTable(section, table),
                        
                        onPrint: () => _showSnack("Fiş yazdırılıyor..."),
                      );
                    },
                  ),
                ),
                
                // --- SAĞ ALT MENÜ BUTONU ---
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: FloatingActionButton(
                    heroTag: section.title,
                    backgroundColor: Colors.redAccent,
                    child: const Icon(Icons.edit_note, size: 35, color: Colors.white),
                    onPressed: () => _showTableOptions(section),
                  ),
                )
              ],
            );
          }).toList(),
        ),
        bottomNavigationBar: Container(
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  isScrollable: true,
                  labelColor: Colors.red,
                  indicatorColor: Colors.red,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  tabs: _currentSections.map((section) {
                    return Tab(text: "${section.title} (${section.activeTableCount})");
                  }).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.redAccent, size: 30),
                  tooltip: 'Bölüm Ekle/Düzenle',
                  onPressed: _showSectionManager,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 1. ÖDEME MANTIĞI ---
  void _handlePayment(Section section, TableModel table, String type) async {
    try {
      await _api.payOrdersByTable(table.name, section.title, type);
    } catch (e) {
      debugPrint('DB ödeme hatası: $e');
    }
    setState(() {
      table.totalAmount = 0.0;
      if (table.isMerged) {
        _handleUnmergeTable(section, table);
      }
    });
    _showSnack("${table.name} için $type ödemesi alındı ve masa temizlendi.");
  }

  // --- 2. İPTAL MANTIĞI ---
  void _handleCancel(Section section, TableModel table, String reason) async {
    try {
      await _api.cancelOrdersByTable(table.name, section.title, reason);
    } catch (e) {
      debugPrint('DB iptal hatası: $e');
    }
    setState(() {
      table.totalAmount = 0.0;
    });
    _showSnack("${table.name} siparişleri iptal edildi. Neden: $reason");
  }

  // --- 3. MASAYI TAŞIMA ---
  void _handleMoveTable(Section section, TableModel sourceTable) {
    _showTargetTableSelectionDialog(
      section: section,
      title: "Hangi masaya taşınacak?",
      excludeTable: sourceTable,
      onSelected: (targetTable) {
        setState(() {
          // 1. Kaynak Masanın verilerini geçici değişkenlere al
          String tempName = sourceTable.name;
          double tempTotal = sourceTable.totalAmount;
          bool tempMerged = sourceTable.isMerged;
          var tempChildren = List<SavedTable>.from(sourceTable.mergedChildren);

          // 2. Hedef Masanın verilerini Kaynak Masaya aktar
          sourceTable.name = targetTable.name;
          sourceTable.totalAmount = targetTable.totalAmount;
          sourceTable.isMerged = targetTable.isMerged;
          sourceTable.mergedChildren = List<SavedTable>.from(targetTable.mergedChildren);

          // 3. Geçici verileri (Eski Kaynak) Hedef Masaya aktar
          targetTable.name = tempName;
          targetTable.totalAmount = tempTotal;
          targetTable.isMerged = tempMerged;
          targetTable.mergedChildren = tempChildren;
        });
        _showSnack("Masa ve tüm siparişler taşındı.");
      },
    );
  }

  // --- 4. ADİSYON AKTAR (YENİ EKLENEN FONKSİYON) ---
  void _handleTransferTable(Section section, TableModel sourceTable) {
    // Eğer masada hesap yoksa uyar
    if (sourceTable.totalAmount <= 0) {
      _showSnack("Bu masada aktarılacak adisyon yok.");
      return;
    }

    _showTargetTableSelectionDialog(
      section: section,
      title: "Siparişler hangi masaya aktarılsın?",
      excludeTable: sourceTable,
      onSelected: (targetTable) {
        setState(() {
          // 1. Kaynak masanın tutarını hedef masaya ekle
          targetTable.totalAmount += sourceTable.totalAmount;

          // 2. Kaynak masayı sıfırla
          sourceTable.totalAmount = 0.0;
        });
        
        _showSnack("${sourceTable.name} siparişleri ${targetTable.name} masasına aktarıldı.");
      },
    );
  }

  // --- 5. MASALARI BİRLEŞTİRME ---
  void _handleMergeTable(Section section, TableModel sourceTable) {
    _showTargetTableSelectionDialog(
      section: section,
      title: "Hangi masa ile birleştirilsin?",
      excludeTable: sourceTable,
      onSelected: (targetTable) {
        setState(() {
          // Eğer hedef masa zaten birleşikse içindekileri al
          if (targetTable.mergedChildren.isNotEmpty) {
            sourceTable.mergedChildren.addAll(targetTable.mergedChildren);
            
            // Hedef masayı temizle
            targetTable.mergedChildren.clear(); 
            targetTable.isMerged = false;
            targetTable.name = targetTable.originalName;
          }

          int targetIndex = section.tables.indexOf(targetTable);

          sourceTable.mergedChildren.add(SavedTable(
            table: targetTable, 
            originalIndex: targetIndex
          ));
          
          sourceTable.isMerged = true;

          String newName = sourceTable.originalName;
          for (var saved in sourceTable.mergedChildren) {
             newName += " + ${saved.table.originalName}";
          }
          sourceTable.name = newName;

          section.tables.remove(targetTable);
        });
        _showSnack("Masalar birleştirildi.");
      },
    );
  }

  // --- 6. MASALARI AYIRMA ---
  void _handleUnmergeTable(Section section, TableModel sourceTable) {
    if (!sourceTable.isMerged) return;

    setState(() {
      sourceTable.name = sourceTable.originalName;
      sourceTable.isMerged = false;

      for (var savedItem in sourceTable.mergedChildren) {
        savedItem.table.isMerged = false;
        savedItem.table.name = savedItem.table.originalName;
        savedItem.table.mergedChildren.clear();
        section.tables.add(savedItem.table);
      }

      sourceTable.mergedChildren.clear();

      // Sıra numarasına göre diz
      section.tables.sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
    });
    
    _showSnack("Masalar ayrıldı ve düzenlendi.");
  }

  // --- HEDEF MASA SEÇİM DİYALOĞU ---
  void _showTargetTableSelectionDialog({
    required Section section,
    required String title,
    required TableModel excludeTable,
    required Function(TableModel) onSelected,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.5
            ),
            itemCount: section.tables.length,
            itemBuilder: (context, index) {
              final target = section.tables[index];
              if (target == excludeTable) return const SizedBox.shrink();

              return InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  onSelected(target);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(target.name, textAlign: TextAlign.center),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // --- SAĞ ALT MENÜ ---
  void _showTableOptions(Section section) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_box, color: Colors.green),
              title: const Text("Masa Ekle"),
              subtitle: const Text("Toplu masa ekler"),
              onTap: () {
                Navigator.pop(context);
                _showAddTableDialog(section);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text("Masa Adı Değiştir"),
              onTap: () {
                Navigator.pop(context);
                _showRenameTableDialog(section);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text("Masa Sil (Seçmeli)"),
              onTap: () {
                Navigator.pop(context);
                _showMultiDeleteDialog(section);
              },
            ),
          ],
        );
      },
    );
  }

  // --- TOPLU MASA EKLEME ---
  void _showAddTableDialog(Section section) {
    final TextEditingController countController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Kaç masa eklensin?"),
          content: TextField(
            controller: countController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: "Sayı girin (Örn: 5)",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("İptal"),
            ),
            ElevatedButton(
              onPressed: () {
                if (countController.text.isNotEmpty) {
                  int amount = int.parse(countController.text);
                  setState(() {
                    int maxSeq = section.tables.isEmpty 
                        ? -1 
                        : section.tables.map((e) => e.sequenceNumber).reduce((curr, next) => curr > next ? curr : next);

                    for (int i = 0; i < amount; i++) {
                      int nextNumber = section.tables.length + 1;
                      int newSeq = maxSeq + 1 + i;

                      section.tables.add(TableModel(
                        id: "${section.title}_${DateTime.now().millisecondsSinceEpoch}_$i", 
                        name: "Masa $nextNumber",
                        sequenceNumber: newSeq,
                      ));
                    }
                  });
                  Navigator.pop(context);
                  _showSnack("$amount masa eklendi.");
                }
              },
              child: const Text("Ekle"),
            ),
          ],
        );
      },
    );
  }

  // --- SEÇMELİ SİLME ---
  void _showMultiDeleteDialog(Section section) {
    List<TableModel> selectedForDelete = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Silinecek Masaları Seç"),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: ListView.builder(
                  itemCount: section.tables.length,
                  itemBuilder: (context, index) {
                    final table = section.tables[index];
                    final isSelected = selectedForDelete.contains(table);

                    return CheckboxListTile(
                      title: Text(table.name),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            selectedForDelete.add(table);
                          } else {
                            selectedForDelete.remove(table);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: () {
                    setState(() {
                      for (var t in selectedForDelete) {
                        section.tables.remove(t);
                      }
                    });
                    Navigator.pop(context);
                    _showSnack("${selectedForDelete.length} masa silindi.");
                  },
                  child: const Text("Seçilenleri Sil"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- MASA ADI DEĞİŞTİRME ---
  void _showRenameTableDialog(Section section) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Adı Değiştirilecek Masayı Seç"),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: section.tables.length,
            itemBuilder: (ctx, index) {
              final table = section.tables[index];
              return ListTile(
                title: Text(table.name),
                trailing: const Icon(Icons.edit, size: 20),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameInput(table);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showRenameInput(TableModel table) {
    TextEditingController controller = TextEditingController(text: table.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Yeni İsim Girin"),
        content: TextField(controller: controller),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() {
                table.name = controller.text;
              });
              Navigator.pop(ctx);
            },
            child: const Text("Kaydet"),
          )
        ],
      ),
    );
  }

  // --- BÖLÜM YÖNETİCİSİ ---
  void _showSectionManager() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Bölümleri Yönet"),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    Expanded(
                      child: ReorderableListView(
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final Section item = _currentSections.removeAt(oldIndex);
                            _currentSections.insert(newIndex, item);
                          });
                          setDialogState(() {});
                        },
                        children: [
                          for (int index = 0; index < _currentSections.length; index++)
                            ListTile(
                              key: ValueKey(_currentSections[index]),
                              title: Text(_currentSections[index].title),
                              leading: const Icon(Icons.drag_handle),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () {
                                      _showRenameSectionDialog(_currentSections[index], setDialogState);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                       setState(() {
                                         _currentSections.removeAt(index);
                                       });
                                       setDialogState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text("Yeni Bölüm Oluştur"),
                      onPressed: () {
                        _showCreateSectionDialog(setDialogState);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Kapat"),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _showRenameSectionDialog(Section section, StateSetter parentSetState) {
    TextEditingController textController = TextEditingController(text: section.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Bölüm Adını Değiştir"),
        content: TextField(controller: textController),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() {
                section.title = textController.text;
              });
              parentSetState(() {});
              Navigator.pop(ctx);
            },
            child: const Text("Kaydet"),
          )
        ],
      ),
    );
  }

  void _showCreateSectionDialog(StateSetter parentSetState) {
    TextEditingController textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Yeni Bölüm Adı"),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(hintText: "Örn: Teras"),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (textController.text.isNotEmpty) {
                setState(() {
                  _currentSections.add(Section(
                    title: textController.text,
                    tables: [], 
                  ));
                });
                parentSetState(() {});
                Navigator.pop(ctx);
              }
            },
            child: const Text("Oluştur"),
          )
        ],
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }
}