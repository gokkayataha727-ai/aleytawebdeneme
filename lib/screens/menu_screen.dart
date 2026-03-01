import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';

class MenuScreen extends StatefulWidget {
  final String tableName;
  final String sectionName;
  final double currentTotal;

  const MenuScreen({
    super.key,
    required this.tableName,
    required this.sectionName,
    required this.currentTotal,
  });

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int selectedCategoryIndex = 0;
  double sessionTotal = 0;
  final ApiService _api = ApiService();
  bool _isLoading = true;

  Map<String, int> selectedCounts = {};

  // DB'den gelen veriler
  List<Map<String, dynamic>> _rawCategories = [];
  List<String> _categoryNames = [];
  Map<String, List<Map<String, dynamic>>> _productsByCategory = {};
  Map<String, String> _categoryTypes = {};

  @override
  void initState() {
    super.initState();
    sessionTotal = widget.currentTotal;
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    try {
      final data = await _api.getCategories();
      setState(() {
        _rawCategories = data;
        _categoryNames = data.map((c) => c['name'] as String).toList();
        _productsByCategory = {};
        _categoryTypes = {};
        for (var c in data) {
          final catName = c['name'] as String;
          _categoryTypes[catName] = c['type'] as String? ?? 'mutfak';
          _productsByCategory[catName] = ((c['products'] as List?) ?? []).map((p) => {
            'id': p['id'],
            'name': p['name'] as String,
            'price': (p['price'] as num).toDouble(),
          }).toList();
        }
        if (selectedCategoryIndex >= _categoryNames.length && _categoryNames.isNotEmpty) {
          selectedCategoryIndex = 0;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Menü yüklenirken hata: $e');
    }
  }

  double _findPrice(String productName) {
    for (var list in _productsByCategory.values) {
      for (var product in list) {
        if (product['name'] == productName) return product['price'];
      }
    }
    return 0.0;
  }

  String _findCategory(String productName) {
    for (var entry in _productsByCategory.entries) {
      for (var product in entry.value) {
        if (product['name'] == productName) return entry.key;
      }
    }
    return '';
  }

  void _updateCount(Map<String, dynamic> product, int change) {
    setState(() {
      String name = product['name'];
      double price = product['price'];
      int currentCount = selectedCounts[name] ?? 0;
      int newCount = currentCount + change;
      if (newCount < 0) return;
      if (newCount == 0) {
        selectedCounts.remove(name);
      } else {
        selectedCounts[name] = newCount;
      }
      sessionTotal += (price * change);
    });
  }

  // Sepetteki toplam ürün sayısı
  int get _totalCartItems => selectedCounts.values.fold(0, (sum, count) => sum + count);

  // === SEPET GÖSTER ===
  void _showCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final cartEntries = selectedCounts.entries.toList();
          return DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.8,
            expand: false,
            builder: (context, scrollController) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shopping_cart, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Text('Sepet ($_totalCartItems ürün)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const Spacer(),
                      Text('₺${sessionTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: cartEntries.isEmpty
                        ? const Center(child: Text('Sepet boş', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: cartEntries.length,
                            itemBuilder: (context, index) {
                              final entry = cartEntries[index];
                              final productName = entry.key;
                              final quantity = entry.value;
                              final price = _findPrice(productName);
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('₺${price.toStringAsFixed(2)} x $quantity = ₺${(price * quantity).toStringAsFixed(2)}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                                        onPressed: () {
                                          setState(() {
                                            if (quantity > 1) {
                                              selectedCounts[productName] = quantity - 1;
                                            } else {
                                              selectedCounts.remove(productName);
                                            }
                                            sessionTotal -= price;
                                          });
                                          setSheetState(() {});
                                        },
                                      ),
                                      Text('$quantity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle, color: Colors.green),
                                        onPressed: () {
                                          setState(() {
                                            selectedCounts[productName] = quantity + 1;
                                            sessionTotal += price;
                                          });
                                          setSheetState(() {});
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () {
                                          setState(() {
                                            selectedCounts.remove(productName);
                                            sessionTotal -= (price * quantity);
                                          });
                                          setSheetState(() {});
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.tableName), backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
        body: const Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    final selectedCatName = _categoryNames.isNotEmpty ? _categoryNames[selectedCategoryIndex] : '';
    final products = _productsByCategory[selectedCatName] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F5),
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.tableName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Toplam: ₺${sessionTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          // SEPET BUTONU
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart, size: 28),
                onPressed: _showCart,
              ),
              if (_totalCartItems > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.yellow, shape: BoxShape.circle),
                    child: Text('$_totalCartItems', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // --- ANA İÇERİK: SOL KATEGORİ + SAĞ ÜRÜNLER ---
          Expanded(
            child: Row(
              children: [
                // ===== SOL PANEL — KATEGORİLER =====
                Container(
                  width: 130,
                  color: const Color(0xFFF0F0F0),
                  child: Column(
                    children: [
                      Expanded(
                        child: _categoryNames.isEmpty
                            ? const Center(child: Text('Kategori\nyok', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)))
                            : ListView.builder(
                                itemCount: _categoryNames.length,
                                itemBuilder: (context, index) {
                                  final isSelected = index == selectedCategoryIndex;
                                  final catName = _categoryNames[index];
                                  final catType = _categoryTypes[catName] ?? 'mutfak';
                                  return InkWell(
                                    onTap: () => setState(() => selectedCategoryIndex = index),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.redAccent : Colors.transparent,
                                        border: const Border(bottom: BorderSide(color: Colors.white, width: 1)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            catName,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              color: isSelected ? Colors.white : Colors.black87,
                                            ),
                                            maxLines: 2, overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            catType == 'ekstralar' ? 'Ekstralar' : 'Mutfak',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: isSelected ? Colors.white70 : (catType == 'ekstralar' ? Colors.orange.shade700 : Colors.blue.shade700),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      // Sol alt — Kategori düzenle butonu
                      Container(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: _showCategoryEditor,
                          icon: const Icon(Icons.settings, size: 16, color: Colors.deepOrange),
                          label: const Text('Düzenle', style: TextStyle(fontSize: 11, color: Colors.deepOrange)),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                    ],
                  ),
                ),

                // ===== SAĞ PANEL — ÜRÜNLER =====
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: products.isEmpty
                            ? const Center(child: Text('Bu kategoride ürün yok', style: TextStyle(color: Colors.grey)))
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  int crossAxisCount = constraints.maxWidth > 500 ? 4 : (constraints.maxWidth > 300 ? 3 : 2);
                                  return GridView.builder(
                                    padding: const EdgeInsets.all(10),
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      childAspectRatio: 1.1,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                    ),
                                    itemCount: products.length,
                                    itemBuilder: (context, index) {
                                      final product = products[index];
                                      final count = selectedCounts[product['name']] ?? 0;
                                      return Card(
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        child: Padding(
                                          padding: const EdgeInsets.all(6),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Flexible(
                                                child: Text(product['name'], textAlign: TextAlign.center,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                                              ),
                                              const SizedBox(height: 2),
                                              Text('₺${product['price'].toStringAsFixed(2)}',
                                                style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 14)),
                                              const SizedBox(height: 6),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  _circleButton(Icons.remove, Colors.red, () => _updateCount(product, -1)),
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                                    child: Text('$count', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                                  ),
                                                  _circleButton(Icons.add, Colors.green, () => _updateCount(product, 1)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                      // Sağ alt — Ürün düzenle butonu (siyah çizgi YOK)
                      Row(
                        children: [
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _categoryNames.isNotEmpty ? _showProductEditor : null,
                            icon: const Icon(Icons.edit, size: 16, color: Colors.deepOrange),
                            label: const Text('Ürünleri Düzenle', style: TextStyle(fontSize: 11, color: Colors.deepOrange)),
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- SİPARİŞ TAMAMLA ---
          Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (selectedCounts.isNotEmpty) {
                    try {
                      Map<bool, List<OrderItemModel>> groupedItems = {false: [], true: []};
                      for (var entry in selectedCounts.entries) {
                        String productName = entry.key;
                        int quantity = entry.value;
                        double price = _findPrice(productName);
                        String categoryName = _findCategory(productName);
                        bool isExtra = _categoryTypes[categoryName] == 'ekstralar';
                        groupedItems[isExtra]!.add(OrderItemModel(
                          productName: productName, categoryName: categoryName, price: price, quantity: quantity,
                        ));
                      }
                      for (var entry in groupedItems.entries) {
                        if (entry.value.isEmpty) continue;
                        bool isExtra = entry.key;
                        double groupTotal = entry.value.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
                        final order = OrderModel(
                          tableName: widget.tableName, sectionName: widget.sectionName,
                          isExtra: isExtra, totalAmount: groupTotal, items: entry.value,
                        );
                        await _api.createOrder(order);
                      }
                    } catch (e) {
                      debugPrint('Sipariş kaydetme hatası: $e');
                    }
                  }
                  if (mounted) Navigator.pop(context, sessionTotal);
                },
                icon: const Icon(Icons.check),
                label: Text("SİPARİŞİ TAMAMLA (${sessionTotal.toStringAsFixed(2)} ₺)"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  // ============================================================
  // KATEGORİ DÜZENLEME
  // ============================================================
  void _showCategoryEditor() {
    final nameCtrl = TextEditingController();
    String newType = 'mutfak';
    int? editingCatId; // null = yeni ekleme, değer = düzenleme
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.6,
            child: Column(
              children: [
                const Text('Kategorileri Düzenle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                // FORM: Ekleme/Düzenleme
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      TextField(controller: nameCtrl, decoration: InputDecoration(labelText: editingCatId != null ? 'Kategori Adını Düzenle' : 'Yeni Kategori Adı', border: const OutlineInputBorder(), isDense: true)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: ChoiceChip(label: const Text('Mutfak'), selected: newType == 'mutfak', selectedColor: Colors.blue.shade100, onSelected: (_) => setSheetState(() => newType = 'mutfak'))),
                          const SizedBox(width: 8),
                          Expanded(child: ChoiceChip(label: const Text('Ekstralar'), selected: newType == 'ekstralar', selectedColor: Colors.orange.shade100, onSelected: (_) => setSheetState(() => newType = 'ekstralar'))),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: editingCatId != null ? Colors.blue : Colors.green, foregroundColor: Colors.white),
                            onPressed: isSaving ? null : () async {
                              if (nameCtrl.text.trim().isEmpty) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Kategori adı boş olamaz'), backgroundColor: Colors.orange),
                                  );
                                }
                                return;
                              }
                              setSheetState(() => isSaving = true);
                              try {
                                if (editingCatId != null) {
                                  await _api.updateCategory(editingCatId!, nameCtrl.text.trim(), newType);
                                } else {
                                  await _api.addCategory(nameCtrl.text.trim(), newType);
                                }
                                nameCtrl.clear();
                                editingCatId = null;
                                newType = 'mutfak';
                                // Menüyü yeniden yükle ve bottom sheet'i güncelle
                                try {
                                  final data = await _api.getCategories();
                                  setState(() {
                                    _rawCategories = data;
                                    _categoryNames = data.map((c) => c['name'] as String).toList();
                                    _productsByCategory = {};
                                    _categoryTypes = {};
                                    for (var c in data) {
                                      final catName = c['name'] as String;
                                      _categoryTypes[catName] = c['type'] as String? ?? 'mutfak';
                                      _productsByCategory[catName] = ((c['products'] as List?) ?? []).map((p) => {
                                        'id': p['id'],
                                        'name': p['name'] as String,
                                        'price': (p['price'] as num).toDouble(),
                                      }).toList();
                                    }
                                    if (selectedCategoryIndex >= _categoryNames.length && _categoryNames.isNotEmpty) {
                                      selectedCategoryIndex = 0;
                                    }
                                  });
                                } catch (e) {
                                  debugPrint('Menü yeniden yüklenirken hata: $e');
                                }
                                setSheetState(() => isSaving = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Kategori başarıyla kaydedildi ✓'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
                                  );
                                }
                              } catch (e) {
                                setSheetState(() => isSaving = false);
                                debugPrint('Kategori işlem hatası: $e');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
                                  );
                                }
                              }
                            },
                            child: isSaving
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(editingCatId != null ? 'Güncelle' : 'Ekle'),
                          ),
                          if (editingCatId != null) ...[
                            const SizedBox(width: 4),
                            IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => setSheetState(() { editingCatId = null; nameCtrl.clear(); newType = 'mutfak'; })),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // LİSTE
                Expanded(
                  child: _rawCategories.isEmpty
                      ? const Center(child: Text('Henüz kategori yok', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: _rawCategories.length,
                          itemBuilder: (context, index) {
                            final cat = _rawCategories[index];
                            final type = cat['type'] as String? ?? 'mutfak';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: ListTile(
                                dense: true,
                                leading: Icon(Icons.category, color: type == 'ekstralar' ? Colors.orange : Colors.blue, size: 20),
                                title: Text(cat['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text(type == 'ekstralar' ? 'Ekstralar' : 'Mutfak', style: TextStyle(fontSize: 11, color: type == 'ekstralar' ? Colors.orange : Colors.blue)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 18), onPressed: () {
                                      setSheetState(() {
                                        editingCatId = cat['id'] as int;
                                        nameCtrl.text = cat['name'] as String;
                                        newType = type;
                                      });
                                    }),
                                    IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 18), onPressed: () async {
                                      try {
                                        await _api.deleteCategory(cat['id'] as int);
                                        try {
                                          final data = await _api.getCategories();
                                          setState(() {
                                            _rawCategories = data;
                                            _categoryNames = data.map((c) => c['name'] as String).toList();
                                            _productsByCategory = {};
                                            _categoryTypes = {};
                                            for (var c in data) {
                                              final catName = c['name'] as String;
                                              _categoryTypes[catName] = c['type'] as String? ?? 'mutfak';
                                              _productsByCategory[catName] = ((c['products'] as List?) ?? []).map((p) => {
                                                'id': p['id'],
                                                'name': p['name'] as String,
                                                'price': (p['price'] as num).toDouble(),
                                              }).toList();
                                            }
                                            if (selectedCategoryIndex >= _categoryNames.length && _categoryNames.isNotEmpty) {
                                              selectedCategoryIndex = 0;
                                            }
                                          });
                                        } catch (e) {
                                          debugPrint('Menü yeniden yüklenirken hata: $e');
                                        }
                                        setSheetState(() {});
                                      } catch (e) {
                                        debugPrint('Kategori silme hatası: $e');
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Silme hatası: $e'), backgroundColor: Colors.red),
                                          );
                                        }
                                      }
                                    }),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ÜRÜN DÜZENLEME
  // ============================================================
  void _showProductEditor() {
    final catName = _categoryNames[selectedCategoryIndex];
    final catData = _rawCategories.firstWhere((c) => c['name'] == catName, orElse: () => <String, dynamic>{});
    final catId = catData['id'] as int? ?? 0;

    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    int? editingProductId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.6,
            child: Column(
              children: [
                Text('"$catName" Ürünleri', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                // FORM
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Expanded(child: TextField(controller: nameCtrl, decoration: InputDecoration(labelText: editingProductId != null ? 'Ürün Adını Düzenle' : 'Yeni Ürün Adı', border: const OutlineInputBorder(), isDense: true))),
                      const SizedBox(width: 8),
                      SizedBox(width: 100, child: TextField(controller: priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Fiyat ₺', border: OutlineInputBorder(), isDense: true))),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: editingProductId != null ? Colors.blue : Colors.green, foregroundColor: Colors.white),
                        onPressed: () async {
                          final price = double.tryParse(priceCtrl.text.trim().replaceAll(',', '.'));
                          if (nameCtrl.text.trim().isEmpty || price == null || price <= 0) return;
                          try {
                            if (editingProductId != null) {
                              await _api.updateProduct(editingProductId!, nameCtrl.text.trim(), price);
                            } else {
                              await _api.addProduct(catId, nameCtrl.text.trim(), price);
                            }
                            nameCtrl.clear();
                            priceCtrl.clear();
                            editingProductId = null;
                            await _loadMenu();
                            setSheetState(() {});
                          } catch (e) {
                            debugPrint('Ürün işlem hatası: $e');
                          }
                        },
                        child: Text(editingProductId != null ? 'Güncelle' : 'Ekle'),
                      ),
                      if (editingProductId != null) ...[
                        const SizedBox(width: 4),
                        IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => setSheetState(() { editingProductId = null; nameCtrl.clear(); priceCtrl.clear(); })),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // LİSTE
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final products = _productsByCategory[catName] ?? [];
                      if (products.isEmpty) return const Center(child: Text('Henüz ürün yok', style: TextStyle(color: Colors.grey)));
                      return ListView.builder(
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final p = products[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.fastfood, color: Colors.grey, size: 20),
                              title: Text(p['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text('₺${(p['price'] as double).toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 18), onPressed: () {
                                    setSheetState(() {
                                      editingProductId = p['id'] as int;
                                      nameCtrl.text = p['name'] as String;
                                      priceCtrl.text = (p['price'] as double).toStringAsFixed(2);
                                    });
                                  }),
                                  IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 18), onPressed: () async {
                                    try {
                                      await _api.deleteProduct(p['id'] as int);
                                      await _loadMenu();
                                      setSheetState(() {});
                                    } catch (e) {
                                      debugPrint('Ürün silme hatası: $e');
                                    }
                                  }),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
