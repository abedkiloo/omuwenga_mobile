import 'package:drift/drift.dart';

/// Mutation outbox — durable queue for offline writes.
class OutboxItems extends Table {
  TextColumn get id => text()();
  TextColumn get clientResourceId => text()();
  TextColumn get idempotencyKey => text()();
  TextColumn get method => text()();
  TextColumn get path => text()();
  TextColumn get bodyJson => text()();
  TextColumn get status => text()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  TextColumn get humanError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Catalog cache placeholder for offline POS reads (S04).
class CachedProducts extends Table {
  TextColumn get id => text()();
  TextColumn get serverId => text().nullable()();
  TextColumn get sku => text().nullable()();

  /// Display name — not PII; kept plaintext for search.
  TextColumn get name => text()();
  RealColumn get price => real().withDefault(const Constant(0))();

  /// Optional AES blob for future sensitive attributes (notes, phones on related entities).
  TextColumn get encryptedPayload => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
