import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      _categories = await _api.getCategories();
    } catch (e) {
      _showSnack('Kategoriler yüklenirken hata: $e');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: const Text('Menü Düzenleme', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.green, size: 30),
            tooltip: 'Yeni Kategori Ekle',
            onPressed: () => _showCategoryDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : _categories.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.category, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Henüz kategori yok', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showCategoryDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Kategori Ekle'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                  ),
                ]))
              : RefreshIndicator(
                  onRefresh: _loadCategories,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) => _buildCategoryCard(_categories[index]),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final products = (category['products'] as List?) ?? [];
    final type = category['type'] as String? ?? 'mutfak';
    final typeLabel = type == 'ekstralar' ? 'Ekstralar' : 'Mutfak';
    final typeColor = type == 'ekstralar' ? Colors.orange : Colors.blue;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(Icons.category, color: typeColor),
        title: Row(
          children: [
            Expanded(child: Text(category['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: typeColor.withOpacity(0.3))),
              child: Text(typeLabel, style: TextStyle(fontSize: 11, color: typeColor, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Text('${products.length} ürün', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
              onPressed: () => _showCategoryDialog(category: category),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () => _confirmDeleteCategory(category),
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          // Ürünler listesi
          ...products.map<Widget>((product) {
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
              dense: true,
              leading: const Icon(Icons.fastfood, size: 20, color: Colors.grey),
              title: Text(product['name'] as String, style: const TextStyle(fontSize: 14)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('₺${(product['price'] as num).toDouble().toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                    onPressed: () => _showProductDialog(category['id'] as int, product: product),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    onPressed: () => _confirmDeleteProduct(product),
                  ),
                ],
              ),
            );
          }),
          // Ürün ekle butonu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _showProductDialog(category['id'] as int),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ürün Ekle'),
              style: TextButton.styleFrom(foregroundColor: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  // === KATEGORİ DİALOG ===
  void _showCategoryDialog({Map<String, dynamic>? category}) {
    final isEdit = category != null;
    final nameController = TextEditingController(text: isEdit ? category['name'] as String : '');
    String selectedType = isEdit ? (category['type'] as String? ?? 'mutfak') : 'mutfak';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Kategori Düzenle' : 'Yeni Kategori'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Kategori Adı', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              const Text('Sipariş türü:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Mutfak'),
                      selected: selectedType == 'mutfak',
                      selectedColor: Colors.blue.shade100,
                      onSelected: (_) => setDialogState(() => selectedType = 'mutfak'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Ekstralar'),
                      selected: selectedType == 'ekstralar',
                      selectedColor: Colors.orange.shade100,
                      onSelected: (_) => setDialogState(() => selectedType = 'ekstralar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  _showSnack('Lütfen kategori adı girin');
                  return;
                }
                Navigator.pop(ctx);
                try {
                  if (isEdit) {
                    await _api.updateCategory(category['id'] as int, nameController.text.trim(), selectedType);
                  } else {
                    await _api.addCategory(nameController.text.trim(), selectedType);
                  }
                  _loadCategories();
                  _showSnack(isEdit ? 'Kategori güncellendi' : 'Kategori eklendi');
                } catch (e) {
                  _showSnack('Hata: $e');
                }
              },
              child: Text(isEdit ? 'Güncelle' : 'Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  // === ÜRÜN DİALOG ===
  void _showProductDialog(int categoryId, {Map<String, dynamic>? product}) {
    final isEdit = product != null;
    final nameController = TextEditingController(text: isEdit ? product['name'] as String : '');
    final priceController = TextEditingController(text: isEdit ? (product['price'] as num).toDouble().toStringAsFixed(2) : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Ürün Düzenle' : 'Yeni Ürün'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Ürün Adı', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Fiyat (₺)', border: OutlineInputBorder(), prefixText: '₺ '),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              if (nameController.text.trim().isEmpty || priceController.text.trim().isEmpty) {
                _showSnack('Tüm alanları doldurun');
                return;
              }
              final price = double.tryParse(priceController.text.trim().replaceAll(',', '.'));
              if (price == null || price <= 0) {
                _showSnack('Geçerli bir fiyat girin');
                return;
              }
              Navigator.pop(ctx);
              try {
                if (isEdit) {
                  await _api.updateProduct(product['id'] as int, nameController.text.trim(), price);
                } else {
                  await _api.addProduct(categoryId, nameController.text.trim(), price);
                }
                _loadCategories();
                _showSnack(isEdit ? 'Ürün güncellendi' : 'Ürün eklendi');
              } catch (e) {
                _showSnack('Hata: $e');
              }
            },
            child: Text(isEdit ? 'Güncelle' : 'Ekle'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(Map<String, dynamic> category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kategori Sil'),
        content: Text('"${category['name']}" kategorisi ve altındaki tüm ürünler silinecek. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteCategory(category['id'] as int);
                _loadCategories();
                _showSnack('"${category['name']}" silindi');
              } catch (e) {
                _showSnack('Hata: $e');
              }
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProduct(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ürün Sil'),
        content: Text('"${product['name']}" ürünü silinecek. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteProduct(product['id'] as int);
                _loadCategories();
                _showSnack('"${product['name']}" silindi');
              } catch (e) {
                _showSnack('Hata: $e');
              }
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }
}
