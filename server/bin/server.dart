import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

Connection? _connection;

/// PostgreSQL DECIMAL sütunları String olarak dönebilir, güvenli dönüşüm:
double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

Future<void> _initDb() async {
  _connection = await Connection.open(
    Endpoint(
      host: 'localhost',
      port: 5432,
      database: 'adisyon_db',
      username: 'postgres',
      password: 'postgres',
    ),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );

  await _connection!.execute('''
    CREATE TABLE IF NOT EXISTS categories (
      id SERIAL PRIMARY KEY,
      name VARCHAR(100) NOT NULL,
      type VARCHAR(20) DEFAULT 'mutfak',
      color VARCHAR(20) DEFAULT 'orange',
      sort_order INTEGER DEFAULT 0
    )
  ''');

  await _connection!.execute('''
    CREATE TABLE IF NOT EXISTS products (
      id SERIAL PRIMARY KEY,
      category_id INTEGER REFERENCES categories(id) ON DELETE CASCADE,
      name VARCHAR(100) NOT NULL,
      price DECIMAL(10,2) NOT NULL,
      sort_order INTEGER DEFAULT 0
    )
  ''');

  await _connection!.execute('''
    CREATE TABLE IF NOT EXISTS orders (
      id SERIAL PRIMARY KEY,
      table_name VARCHAR(50) NOT NULL,
      section_name VARCHAR(50) NOT NULL,
      status VARCHAR(20) DEFAULT 'siparis_alindi',
      is_extra BOOLEAN DEFAULT FALSE,
      total_amount DECIMAL(10,2) NOT NULL,
      discount_amount DECIMAL(10,2) DEFAULT 0,
      payment_type VARCHAR(20),
      cancel_reason TEXT,
      created_at TIMESTAMP DEFAULT NOW(),
      paid_at TIMESTAMP,
      cancelled_at TIMESTAMP
    )
  ''');

  await _connection!.execute('''
    CREATE TABLE IF NOT EXISTS order_items (
      id SERIAL PRIMARY KEY,
      order_id INTEGER REFERENCES orders(id) ON DELETE CASCADE,
      product_name VARCHAR(100) NOT NULL,
      category_name VARCHAR(50) NOT NULL,
      price DECIMAL(10,2) NOT NULL,
      quantity INTEGER NOT NULL
    )
  ''');

  // discount_amount sütununu ekle (mevcut tablolarda yoksa)
  await _connection!.execute('''
    DO \$\$ BEGIN
      ALTER TABLE orders ADD COLUMN IF NOT EXISTS discount_amount DECIMAL(10,2) DEFAULT 0;
    EXCEPTION WHEN duplicate_column THEN NULL;
    END \$\$;
  ''');

  // Varsayılan kategorileri ekle (tablo boşsa)
  final catCount = await _connection!.execute('SELECT COUNT(*) FROM categories');
  if ((catCount.first[0] as int) == 0) {
    final defaults = [
      {'name': 'Sıcak İçecekler', 'type': 'mutfak', 'color': 'orange', 'sort': 0},
      {'name': 'Soğuk İçecekler', 'type': 'mutfak', 'color': 'blue', 'sort': 1},
      {'name': 'Tatlılar', 'type': 'mutfak', 'color': 'pink', 'sort': 2},
      {'name': 'Kahvaltı', 'type': 'mutfak', 'color': 'green', 'sort': 3},
      {'name': 'Ana Yemek', 'type': 'mutfak', 'color': 'red', 'sort': 4},
      {'name': 'Atıştırmalıklar', 'type': 'ekstralar', 'color': 'teal', 'sort': 5},
    ];

    for (var cat in defaults) {
      final result = await _connection!.execute(
        Sql.named("INSERT INTO categories (name, type, color, sort_order) VALUES (@name, @type, @color, @sort) RETURNING id"),
        parameters: {'name': cat['name'], 'type': cat['type'], 'color': cat['color'], 'sort': cat['sort']},
      );
      final catId = result.first[0] as int;

      List<Map<String, dynamic>> products = [];
      switch (cat['name']) {
        case 'Sıcak İçecekler':
          products = [{'name': 'Çay', 'price': 30.0}, {'name': 'Türk Kahvesi', 'price': 90.0}, {'name': 'Espresso', 'price': 100.0}, {'name': 'Latte', 'price': 120.0}];
          break;
        case 'Soğuk İçecekler':
          products = [{'name': 'Limonata', 'price': 80.0}, {'name': 'Ayran', 'price': 40.0}, {'name': 'Kola', 'price': 60.0}, {'name': 'Su', 'price': 20.0}];
          break;
        case 'Tatlılar':
          products = [{'name': 'Cheesecake', 'price': 150.0}, {'name': 'Tiramisu', 'price': 140.0}, {'name': 'Baklava', 'price': 200.0}];
          break;
        case 'Kahvaltı':
          products = [{'name': 'Serpme Kahvaltı', 'price': 400.0}, {'name': 'Sahanda Yumurta', 'price': 120.0}, {'name': 'Menemen', 'price': 140.0}];
          break;
        case 'Ana Yemek':
          products = [{'name': 'Izgara Köfte', 'price': 350.0}, {'name': 'Hamburger', 'price': 300.0}, {'name': 'Makarna', 'price': 220.0}];
          break;
        case 'Atıştırmalıklar':
          products = [{'name': 'Patates Kızartması', 'price': 100.0}, {'name': 'Sigara Böreği', 'price': 120.0}, {'name': 'Çıtır Tavuk', 'price': 180.0}];
          break;
      }

      for (int i = 0; i < products.length; i++) {
        await _connection!.execute(
          Sql.named("INSERT INTO products (category_id, name, price, sort_order) VALUES (@catId, @name, @price, @sort)"),
          parameters: {'catId': catId, 'name': products[i]['name'], 'price': products[i]['price'], 'sort': i},
        );
      }
    }
  }
}

// --- CORS Middleware ---
Middleware corsHeaders() {
  return (Handler handler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeadersMap);
      }
      final response = await handler(request);
      return response.change(headers: _corsHeadersMap);
    };
  };
}

const _corsHeadersMap = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

Response jsonResponse(Object data, {int statusCode = 200}) {
  return Response(statusCode,
      body: jsonEncode(data),
      headers: {'Content-Type': 'application/json', ..._corsHeadersMap});
}

Future<Map<String, dynamic>> parseBody(Request request) async {
  final body = await request.readAsString();
  return jsonDecode(body) as Map<String, dynamic>;
}

// ------------- API ROUTER ---------------
Router buildRouter() {
  final router = Router();

  // ============ KATEGORİLER ============

  // Tüm kategorileri getir (ürünlerle birlikte)
  router.get('/api/categories', (Request request) async {
    try {
      final cats = await _connection!.execute('SELECT * FROM categories ORDER BY sort_order');
      List<Map<String, dynamic>> result = [];
      for (var row in cats) {
        final m = row.toColumnMap();
        final catId = m['id'] as int;
        final prods = await _connection!.execute(
          Sql.named('SELECT * FROM products WHERE category_id = @catId ORDER BY sort_order'),
          parameters: {'catId': catId},
        );
        result.add({
          'id': catId,
          'name': m['name'],
          'type': m['type'],
          'color': m['color'],
          'sort_order': m['sort_order'],
          'products': prods.map((r) {
            final p = r.toColumnMap();
            return {'id': p['id'], 'name': p['name'], 'price': _toDouble(p['price']), 'sort_order': p['sort_order']};
          }).toList(),
        });
      }
      return jsonResponse(result);
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Kategori ekle
  router.post('/api/categories', (Request request) async {
    try {
      final body = await parseBody(request);
      final result = await _connection!.execute(
        Sql.named("INSERT INTO categories (name, type, color, sort_order) VALUES (@name, @type, @color, @sort) RETURNING id"),
        parameters: {'name': body['name'], 'type': body['type'] ?? 'mutfak', 'color': body['color'] ?? 'orange', 'sort': body['sort_order'] ?? 0},
      );
      return jsonResponse({'id': result.first[0], 'message': 'Kategori eklendi'});
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Kategori güncelle
  router.put('/api/categories/<id>', (Request request, String id) async {
    try {
      final body = await parseBody(request);
      await _connection!.execute(
        Sql.named("UPDATE categories SET name = @name, type = @type, color = @color WHERE id = @id"),
        parameters: {'id': int.parse(id), 'name': body['name'], 'type': body['type'], 'color': body['color'] ?? 'orange'},
      );
      return jsonResponse({'message': 'Kategori güncellendi'});
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Kategori sil
  router.delete('/api/categories/<id>', (Request request, String id) async {
    try {
      await _connection!.execute(Sql.named("DELETE FROM categories WHERE id = @id"), parameters: {'id': int.parse(id)});
      return jsonResponse({'message': 'Kategori silindi'});
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // ============ ÜRÜNLER ============

  // Ürün ekle
  router.post('/api/products', (Request request) async {
    try {
      final body = await parseBody(request);
      final result = await _connection!.execute(
        Sql.named("INSERT INTO products (category_id, name, price, sort_order) VALUES (@catId, @name, @price, @sort) RETURNING id"),
        parameters: {'catId': body['category_id'], 'name': body['name'], 'price': body['price'], 'sort': body['sort_order'] ?? 0},
      );
      return jsonResponse({'id': result.first[0], 'message': 'Ürün eklendi'});
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Ürün güncelle
  router.put('/api/products/<id>', (Request request, String id) async {
    try {
      final body = await parseBody(request);
      await _connection!.execute(
        Sql.named("UPDATE products SET name = @name, price = @price WHERE id = @id"),
        parameters: {'id': int.parse(id), 'name': body['name'], 'price': body['price']},
      );
      return jsonResponse({'message': 'Ürün güncellendi'});
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Ürün sil
  router.delete('/api/products/<id>', (Request request, String id) async {
    try {
      await _connection!.execute(Sql.named("DELETE FROM products WHERE id = @id"), parameters: {'id': int.parse(id)});
      return jsonResponse({'message': 'Ürün silindi'});
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // ============ SİPARİŞLER ============

  // Sipariş oluştur
  router.post('/api/orders', (Request request) async {
    try {
      final body = await parseBody(request);
      final result = await _connection!.execute(
        Sql.named('''
          INSERT INTO orders (table_name, section_name, status, is_extra, total_amount, discount_amount, created_at)
          VALUES (@tableName, @sectionName, @status, @isExtra, @totalAmount, @discount, @createdAt)
          RETURNING id
        '''),
        parameters: {
          'tableName': body['table_name'],
          'sectionName': body['section_name'],
          'status': body['status'] ?? 'siparis_alindi',
          'isExtra': body['is_extra'] ?? false,
          'totalAmount': body['total_amount'],
          'discount': body['discount_amount'] ?? 0,
          'createdAt': DateTime.now(),
        },
      );
      final orderId = result.first[0] as int;

      if (body['items'] != null) {
        for (var item in body['items'] as List) {
          await _connection!.execute(
            Sql.named("INSERT INTO order_items (order_id, product_name, category_name, price, quantity) VALUES (@orderId, @productName, @categoryName, @price, @quantity)"),
            parameters: {
              'orderId': orderId,
              'productName': item['product_name'],
              'categoryName': item['category_name'],
              'price': item['price'],
              'quantity': item['quantity'],
            },
          );
        }
      }
      return jsonResponse({'id': orderId, 'message': 'Sipariş oluşturuldu'});
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Aktif siparişler
  router.get('/api/orders/active', (Request request) async {
    try {
      final isExtra = request.url.queryParameters['is_extra'] == 'true';
      final result = await _connection!.execute(
        Sql.named("SELECT * FROM orders WHERE status NOT IN ('odendi', 'iptal') AND is_extra = @isExtra ORDER BY created_at DESC"),
        parameters: {'isExtra': isExtra},
      );

      List<Map<String, dynamic>> orders = [];
      for (var row in result) {
        final map = row.toColumnMap();
        final orderId = map['id'] as int;
        final itemsResult = await _connection!.execute(
          Sql.named('SELECT * FROM order_items WHERE order_id = @orderId'),
          parameters: {'orderId': orderId},
        );
        orders.add({
          'id': orderId,
          'table_name': map['table_name'],
          'section_name': map['section_name'],
          'status': map['status'],
          'is_extra': map['is_extra'],
          'total_amount': _toDouble(map['total_amount']),
          'discount_amount': _toDouble(map['discount_amount']),
          'payment_type': map['payment_type'],
          'cancel_reason': map['cancel_reason'],
          'created_at': map['created_at']?.toString(),
          'paid_at': map['paid_at']?.toString(),
          'cancelled_at': map['cancelled_at']?.toString(),
          'items': itemsResult.map((r) {
            final m = r.toColumnMap();
            return {'id': m['id'], 'product_name': m['product_name'], 'category_name': m['category_name'], 'price': _toDouble(m['price']), 'quantity': m['quantity']};
          }).toList(),
        });
      }
      return jsonResponse(orders);
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Sipariş durumu güncelle
  router.put('/api/orders/<id>/status', (Request request, String id) async {
    try {
      final body = await parseBody(request);
      final status = body['status'] as String;
      final orderId = int.parse(id);
      String extraFields = '';
      Map<String, dynamic> params = {'orderId': orderId, 'status': status};

      if (status == 'odendi') {
        extraFields = ', payment_type = @paymentType, paid_at = @paidAt';
        params['paymentType'] = body['payment_type'] ?? 'nakit';
        params['paidAt'] = DateTime.now();
      } else if (status == 'iptal') {
        extraFields = ', cancel_reason = @cancelReason, cancelled_at = @cancelledAt';
        params['cancelReason'] = body['cancel_reason'] ?? '';
        params['cancelledAt'] = DateTime.now();
      }

      await _connection!.execute(
        Sql.named('UPDATE orders SET status = @status $extraFields WHERE id = @orderId'),
        parameters: params,
      );
      return jsonResponse({'message': 'Durum güncellendi'});
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Masa bazlı ödeme
  router.put('/api/orders/table/pay', (Request request) async {
    try {
      final body = await parseBody(request);
      await _connection!.execute(
        Sql.named("UPDATE orders SET status = 'odendi', payment_type = @paymentType, paid_at = @paidAt WHERE table_name = @tableName AND section_name = @sectionName AND status NOT IN ('odendi', 'iptal')"),
        parameters: {'tableName': body['table_name'], 'sectionName': body['section_name'], 'paymentType': body['payment_type'], 'paidAt': DateTime.now()},
      );
      return jsonResponse({'message': 'Ödeme alındı'});
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Masa bazlı iptal
  router.put('/api/orders/table/cancel', (Request request) async {
    try {
      final body = await parseBody(request);
      await _connection!.execute(
        Sql.named("UPDATE orders SET status = 'iptal', cancel_reason = @reason, cancelled_at = @cancelledAt WHERE table_name = @tableName AND section_name = @sectionName AND status NOT IN ('odendi', 'iptal')"),
        parameters: {'tableName': body['table_name'], 'sectionName': body['section_name'], 'reason': body['cancel_reason'], 'cancelledAt': DateTime.now()},
      );
      return jsonResponse({'message': 'İptal edildi'});
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Sipariş geçmişi
  router.get('/api/orders/history', (Request request) async {
    try {
      final result = await _connection!.execute(Sql.named("SELECT * FROM orders WHERE status IN ('odendi', 'iptal') ORDER BY COALESCE(paid_at, cancelled_at) DESC"));
      final orders = result.map((row) {
        final m = row.toColumnMap();
        return {
          'id': m['id'], 'table_name': m['table_name'], 'section_name': m['section_name'],
          'status': m['status'], 'is_extra': m['is_extra'],
          'total_amount': _toDouble(m['total_amount']),
          'discount_amount': _toDouble(m['discount_amount']),
          'payment_type': m['payment_type'], 'cancel_reason': m['cancel_reason'],
          'created_at': m['created_at']?.toString(), 'paid_at': m['paid_at']?.toString(), 'cancelled_at': m['cancelled_at']?.toString(),
        };
      }).toList();
      return jsonResponse(orders);
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // ============ RAPORLAR ============

  // Günlük istatistikler
  router.get('/api/reports/daily', (Request request) async {
    try {
      final paidResult = await _connection!.execute(Sql.named("SELECT COUNT(*) FROM orders WHERE status = 'odendi' AND DATE(paid_at) = CURRENT_DATE"));
      final paidCount = paidResult.first[0] as int;
      final activeResult = await _connection!.execute(Sql.named("SELECT COUNT(*) FROM orders WHERE status NOT IN ('odendi', 'iptal')"));
      final activeCount = activeResult.first[0] as int;
      return jsonResponse({'paid_count': paidCount, 'active_count': activeCount});
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Saat bazlı ödemeler
  router.get('/api/reports/hourly', (Request request) async {
    try {
      final result = await _connection!.execute(Sql.named("SELECT EXTRACT(HOUR FROM paid_at)::int as hour, COUNT(*) as cnt FROM orders WHERE status = 'odendi' AND DATE(paid_at) = CURRENT_DATE GROUP BY hour ORDER BY hour"));
      Map<String, int> hourly = {};
      for (var row in result) { hourly[row[0].toString()] = row[1] as int; }
      return jsonResponse(hourly);
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Ödeme tipleri dağılımı
  router.get('/api/reports/payment-types', (Request request) async {
    try {
      final result = await _connection!.execute(Sql.named("SELECT payment_type, COUNT(*) as cnt FROM orders WHERE status = 'odendi' AND DATE(paid_at) = CURRENT_DATE GROUP BY payment_type"));
      Map<String, int> dist = {};
      for (var row in result) { dist[(row[0] as String?) ?? 'Bilinmiyor'] = row[1] as int; }
      return jsonResponse(dist);
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Durum dağılımı
  router.get('/api/reports/status-distribution', (Request request) async {
    try {
      final result = await _connection!.execute(Sql.named('SELECT status, COUNT(*) as cnt FROM orders GROUP BY status'));
      Map<String, int> dist = {};
      for (var row in result) { dist[row[0] as String] = row[1] as int; }
      return jsonResponse(dist);
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Ciro raporu (günlük)
  router.get('/api/reports/revenue', (Request request) async {
    try {
      final todayResult = await _connection!.execute(Sql.named("SELECT COALESCE(SUM(total_amount), 0) FROM orders WHERE status = 'odendi' AND DATE(paid_at) = CURRENT_DATE"));
      final todayRevenue = _toDouble(todayResult.first[0]);
      final totalResult = await _connection!.execute(Sql.named("SELECT COALESCE(SUM(total_amount), 0) FROM orders WHERE status = 'odendi'"));
      final totalRevenue = _toDouble(totalResult.first[0]);
      final orderCountResult = await _connection!.execute(Sql.named("SELECT COUNT(*) FROM orders WHERE status = 'odendi' AND DATE(paid_at) = CURRENT_DATE"));
      final orderCount = orderCountResult.first[0] as int;
      return jsonResponse({'today_revenue': todayRevenue, 'total_revenue': totalRevenue, 'today_order_count': orderCount});
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // İndirimler raporu (günlük)
  router.get('/api/reports/discounts', (Request request) async {
    try {
      final result = await _connection!.execute(Sql.named("SELECT COALESCE(SUM(discount_amount), 0), COUNT(*) FILTER (WHERE discount_amount > 0) FROM orders WHERE status = 'odendi' AND DATE(paid_at) = CURRENT_DATE"));
      final totalDiscount = _toDouble(result.first[0]);
      final discountCount = result.first[1] as int;
      return jsonResponse({'total_discount': totalDiscount, 'discount_count': discountCount});
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Fişler (masa bazında tamamlanmış sipariş sayısı)
  router.get('/api/receipts', (Request request) async {
    try {
      final result = await _connection!.execute(Sql.named('''
        SELECT table_name, section_name, COUNT(*) as receipt_count,
               SUM(total_amount) as total
        FROM orders WHERE status = 'odendi'
        GROUP BY table_name, section_name ORDER BY table_name
      '''));
      final receipts = result.map((row) {
        final m = row.toColumnMap();
        return {
          'table_name': m['table_name'], 'section_name': m['section_name'],
          'receipt_count': m['receipt_count'], 'total': _toDouble(m['total']),
        };
      }).toList();
      return jsonResponse(receipts);
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  return router;
}

// ------------- MAIN ---------------
void main(List<String> args) async {
  print('🔌 PostgreSQL bağlantısı kuruluyor...');
  await _initDb();
  print('✅ Veritabanı bağlantısı başarılı');

  final router = buildRouter();
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(router.call);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('🚀 API sunucusu çalışıyor: http://localhost:${server.port}');
}
