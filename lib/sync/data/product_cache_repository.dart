import 'package:drift/drift.dart';

import 'app_database.dart';
import 'pii_cipher.dart';

class ProductCacheEntry {
  const ProductCacheEntry({
    required this.id,
    required this.name,
    required this.price,
    required this.updatedAt,
    this.serverId,
    this.sku,
    this.sensitiveNote,
  });

  final String id;
  final String? serverId;
  final String? sku;
  final String name;
  final double price;
  final DateTime updatedAt;
  final String? sensitiveNote;
}

/// Placeholder catalog cache for S04 offline POS reads.
class ProductCacheRepository {
  ProductCacheRepository(this._db, {AesPiiCipher? cipher}) : _cipher = cipher;

  final AppDatabase _db;
  final AesPiiCipher? _cipher;

  Future<void> upsert(ProductCacheEntry product) async {
    String? encrypted;
    if (product.sensitiveNote != null && _cipher != null) {
      encrypted = await _cipher.encryptUtf8(product.sensitiveNote!);
    }
    await _db.into(_db.cachedProducts).insertOnConflictUpdate(
          CachedProductsCompanion.insert(
            id: product.id,
            serverId: Value(product.serverId),
            sku: Value(product.sku),
            name: product.name,
            price: Value(product.price),
            encryptedPayload: Value(encrypted),
            updatedAt: product.updatedAt,
          ),
        );
  }

  Future<ProductCacheEntry?> findById(String id) async {
    final row = await (_db.select(_db.cachedProducts)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    String? note;
    if (row.encryptedPayload != null && _cipher != null) {
      note = await _cipher.decryptUtf8(row.encryptedPayload!);
    }
    return ProductCacheEntry(
      id: row.id,
      serverId: row.serverId,
      sku: row.sku,
      name: row.name,
      price: row.price,
      updatedAt: row.updatedAt,
      sensitiveNote: note,
    );
  }

  Future<List<ProductCacheEntry>> listAll() async {
    final rows = await _db.select(_db.cachedProducts).get();
    final out = <ProductCacheEntry>[];
    for (final row in rows) {
      String? note;
      if (row.encryptedPayload != null && _cipher != null) {
        note = await _cipher.decryptUtf8(row.encryptedPayload!);
      }
      out.add(
        ProductCacheEntry(
          id: row.id,
          serverId: row.serverId,
          sku: row.sku,
          name: row.name,
          price: row.price,
          updatedAt: row.updatedAt,
          sensitiveNote: note,
        ),
      );
    }
    return out;
  }
}
