// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $OutboxItemsTable extends OutboxItems
    with TableInfo<$OutboxItemsTable, OutboxItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientResourceIdMeta = const VerificationMeta(
    'clientResourceId',
  );
  @override
  late final GeneratedColumn<String> clientResourceId = GeneratedColumn<String>(
    'client_resource_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyJsonMeta = const VerificationMeta(
    'bodyJson',
  );
  @override
  late final GeneratedColumn<String> bodyJson = GeneratedColumn<String>(
    'body_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _humanErrorMeta = const VerificationMeta(
    'humanError',
  );
  @override
  late final GeneratedColumn<String> humanError = GeneratedColumn<String>(
    'human_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientResourceId,
    idempotencyKey,
    method,
    path,
    bodyJson,
    status,
    attemptCount,
    createdAt,
    nextAttemptAt,
    lastError,
    humanError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('client_resource_id')) {
      context.handle(
        _clientResourceIdMeta,
        clientResourceId.isAcceptableOrUnknown(
          data['client_resource_id']!,
          _clientResourceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientResourceIdMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('body_json')) {
      context.handle(
        _bodyJsonMeta,
        bodyJson.isAcceptableOrUnknown(data['body_json']!, _bodyJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyJsonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('human_error')) {
      context.handle(
        _humanErrorMeta,
        humanError.isAcceptableOrUnknown(data['human_error']!, _humanErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      clientResourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_resource_id'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      bodyJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_json'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      humanError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}human_error'],
      ),
    );
  }

  @override
  $OutboxItemsTable createAlias(String alias) {
    return $OutboxItemsTable(attachedDatabase, alias);
  }
}

class OutboxItem extends DataClass implements Insertable<OutboxItem> {
  final String id;
  final String clientResourceId;
  final String idempotencyKey;
  final String method;
  final String path;
  final String bodyJson;
  final String status;
  final int attemptCount;
  final DateTime createdAt;
  final DateTime? nextAttemptAt;
  final String? lastError;
  final String? humanError;
  const OutboxItem({
    required this.id,
    required this.clientResourceId,
    required this.idempotencyKey,
    required this.method,
    required this.path,
    required this.bodyJson,
    required this.status,
    required this.attemptCount,
    required this.createdAt,
    this.nextAttemptAt,
    this.lastError,
    this.humanError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['client_resource_id'] = Variable<String>(clientResourceId);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['method'] = Variable<String>(method);
    map['path'] = Variable<String>(path);
    map['body_json'] = Variable<String>(bodyJson);
    map['status'] = Variable<String>(status);
    map['attempt_count'] = Variable<int>(attemptCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || humanError != null) {
      map['human_error'] = Variable<String>(humanError);
    }
    return map;
  }

  OutboxItemsCompanion toCompanion(bool nullToAbsent) {
    return OutboxItemsCompanion(
      id: Value(id),
      clientResourceId: Value(clientResourceId),
      idempotencyKey: Value(idempotencyKey),
      method: Value(method),
      path: Value(path),
      bodyJson: Value(bodyJson),
      status: Value(status),
      attemptCount: Value(attemptCount),
      createdAt: Value(createdAt),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      humanError: humanError == null && nullToAbsent
          ? const Value.absent()
          : Value(humanError),
    );
  }

  factory OutboxItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxItem(
      id: serializer.fromJson<String>(json['id']),
      clientResourceId: serializer.fromJson<String>(json['clientResourceId']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      method: serializer.fromJson<String>(json['method']),
      path: serializer.fromJson<String>(json['path']),
      bodyJson: serializer.fromJson<String>(json['bodyJson']),
      status: serializer.fromJson<String>(json['status']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      humanError: serializer.fromJson<String?>(json['humanError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'clientResourceId': serializer.toJson<String>(clientResourceId),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'method': serializer.toJson<String>(method),
      'path': serializer.toJson<String>(path),
      'bodyJson': serializer.toJson<String>(bodyJson),
      'status': serializer.toJson<String>(status),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'lastError': serializer.toJson<String?>(lastError),
      'humanError': serializer.toJson<String?>(humanError),
    };
  }

  OutboxItem copyWith({
    String? id,
    String? clientResourceId,
    String? idempotencyKey,
    String? method,
    String? path,
    String? bodyJson,
    String? status,
    int? attemptCount,
    DateTime? createdAt,
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    Value<String?> humanError = const Value.absent(),
  }) => OutboxItem(
    id: id ?? this.id,
    clientResourceId: clientResourceId ?? this.clientResourceId,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    method: method ?? this.method,
    path: path ?? this.path,
    bodyJson: bodyJson ?? this.bodyJson,
    status: status ?? this.status,
    attemptCount: attemptCount ?? this.attemptCount,
    createdAt: createdAt ?? this.createdAt,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    humanError: humanError.present ? humanError.value : this.humanError,
  );
  OutboxItem copyWithCompanion(OutboxItemsCompanion data) {
    return OutboxItem(
      id: data.id.present ? data.id.value : this.id,
      clientResourceId: data.clientResourceId.present
          ? data.clientResourceId.value
          : this.clientResourceId,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      method: data.method.present ? data.method.value : this.method,
      path: data.path.present ? data.path.value : this.path,
      bodyJson: data.bodyJson.present ? data.bodyJson.value : this.bodyJson,
      status: data.status.present ? data.status.value : this.status,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      humanError: data.humanError.present
          ? data.humanError.value
          : this.humanError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxItem(')
          ..write('id: $id, ')
          ..write('clientResourceId: $clientResourceId, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('method: $method, ')
          ..write('path: $path, ')
          ..write('bodyJson: $bodyJson, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('humanError: $humanError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientResourceId,
    idempotencyKey,
    method,
    path,
    bodyJson,
    status,
    attemptCount,
    createdAt,
    nextAttemptAt,
    lastError,
    humanError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxItem &&
          other.id == this.id &&
          other.clientResourceId == this.clientResourceId &&
          other.idempotencyKey == this.idempotencyKey &&
          other.method == this.method &&
          other.path == this.path &&
          other.bodyJson == this.bodyJson &&
          other.status == this.status &&
          other.attemptCount == this.attemptCount &&
          other.createdAt == this.createdAt &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.lastError == this.lastError &&
          other.humanError == this.humanError);
}

class OutboxItemsCompanion extends UpdateCompanion<OutboxItem> {
  final Value<String> id;
  final Value<String> clientResourceId;
  final Value<String> idempotencyKey;
  final Value<String> method;
  final Value<String> path;
  final Value<String> bodyJson;
  final Value<String> status;
  final Value<int> attemptCount;
  final Value<DateTime> createdAt;
  final Value<DateTime?> nextAttemptAt;
  final Value<String?> lastError;
  final Value<String?> humanError;
  final Value<int> rowid;
  const OutboxItemsCompanion({
    this.id = const Value.absent(),
    this.clientResourceId = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.method = const Value.absent(),
    this.path = const Value.absent(),
    this.bodyJson = const Value.absent(),
    this.status = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.humanError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxItemsCompanion.insert({
    required String id,
    required String clientResourceId,
    required String idempotencyKey,
    required String method,
    required String path,
    required String bodyJson,
    required String status,
    this.attemptCount = const Value.absent(),
    required DateTime createdAt,
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.humanError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       clientResourceId = Value(clientResourceId),
       idempotencyKey = Value(idempotencyKey),
       method = Value(method),
       path = Value(path),
       bodyJson = Value(bodyJson),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<OutboxItem> custom({
    Expression<String>? id,
    Expression<String>? clientResourceId,
    Expression<String>? idempotencyKey,
    Expression<String>? method,
    Expression<String>? path,
    Expression<String>? bodyJson,
    Expression<String>? status,
    Expression<int>? attemptCount,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? nextAttemptAt,
    Expression<String>? lastError,
    Expression<String>? humanError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientResourceId != null) 'client_resource_id': clientResourceId,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (method != null) 'method': method,
      if (path != null) 'path': path,
      if (bodyJson != null) 'body_json': bodyJson,
      if (status != null) 'status': status,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (createdAt != null) 'created_at': createdAt,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (lastError != null) 'last_error': lastError,
      if (humanError != null) 'human_error': humanError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? clientResourceId,
    Value<String>? idempotencyKey,
    Value<String>? method,
    Value<String>? path,
    Value<String>? bodyJson,
    Value<String>? status,
    Value<int>? attemptCount,
    Value<DateTime>? createdAt,
    Value<DateTime?>? nextAttemptAt,
    Value<String?>? lastError,
    Value<String?>? humanError,
    Value<int>? rowid,
  }) {
    return OutboxItemsCompanion(
      id: id ?? this.id,
      clientResourceId: clientResourceId ?? this.clientResourceId,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      method: method ?? this.method,
      path: path ?? this.path,
      bodyJson: bodyJson ?? this.bodyJson,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      createdAt: createdAt ?? this.createdAt,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: lastError ?? this.lastError,
      humanError: humanError ?? this.humanError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (clientResourceId.present) {
      map['client_resource_id'] = Variable<String>(clientResourceId.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (bodyJson.present) {
      map['body_json'] = Variable<String>(bodyJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (humanError.present) {
      map['human_error'] = Variable<String>(humanError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxItemsCompanion(')
          ..write('id: $id, ')
          ..write('clientResourceId: $clientResourceId, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('method: $method, ')
          ..write('path: $path, ')
          ..write('bodyJson: $bodyJson, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('humanError: $humanError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedProductsTable extends CachedProducts
    with TableInfo<$CachedProductsTable, CachedProduct> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _skuMeta = const VerificationMeta('sku');
  @override
  late final GeneratedColumn<String> sku = GeneratedColumn<String>(
    'sku',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<double> price = GeneratedColumn<double>(
    'price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _encryptedPayloadMeta = const VerificationMeta(
    'encryptedPayload',
  );
  @override
  late final GeneratedColumn<String> encryptedPayload = GeneratedColumn<String>(
    'encrypted_payload',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    sku,
    name,
    price,
    encryptedPayload,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_products';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedProduct> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('sku')) {
      context.handle(
        _skuMeta,
        sku.isAcceptableOrUnknown(data['sku']!, _skuMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    }
    if (data.containsKey('encrypted_payload')) {
      context.handle(
        _encryptedPayloadMeta,
        encryptedPayload.isAcceptableOrUnknown(
          data['encrypted_payload']!,
          _encryptedPayloadMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedProduct map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedProduct(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      sku: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sku'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price'],
      )!,
      encryptedPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_payload'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CachedProductsTable createAlias(String alias) {
    return $CachedProductsTable(attachedDatabase, alias);
  }
}

class CachedProduct extends DataClass implements Insertable<CachedProduct> {
  final String id;
  final String? serverId;
  final String? sku;

  /// Display name — not PII; kept plaintext for search.
  final String name;
  final double price;

  /// Optional AES blob for future sensitive attributes (notes, phones on related entities).
  final String? encryptedPayload;
  final DateTime updatedAt;
  const CachedProduct({
    required this.id,
    this.serverId,
    this.sku,
    required this.name,
    required this.price,
    this.encryptedPayload,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    if (!nullToAbsent || sku != null) {
      map['sku'] = Variable<String>(sku);
    }
    map['name'] = Variable<String>(name);
    map['price'] = Variable<double>(price);
    if (!nullToAbsent || encryptedPayload != null) {
      map['encrypted_payload'] = Variable<String>(encryptedPayload);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CachedProductsCompanion toCompanion(bool nullToAbsent) {
    return CachedProductsCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      sku: sku == null && nullToAbsent ? const Value.absent() : Value(sku),
      name: Value(name),
      price: Value(price),
      encryptedPayload: encryptedPayload == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptedPayload),
      updatedAt: Value(updatedAt),
    );
  }

  factory CachedProduct.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedProduct(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      sku: serializer.fromJson<String?>(json['sku']),
      name: serializer.fromJson<String>(json['name']),
      price: serializer.fromJson<double>(json['price']),
      encryptedPayload: serializer.fromJson<String?>(json['encryptedPayload']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<String?>(serverId),
      'sku': serializer.toJson<String?>(sku),
      'name': serializer.toJson<String>(name),
      'price': serializer.toJson<double>(price),
      'encryptedPayload': serializer.toJson<String?>(encryptedPayload),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CachedProduct copyWith({
    String? id,
    Value<String?> serverId = const Value.absent(),
    Value<String?> sku = const Value.absent(),
    String? name,
    double? price,
    Value<String?> encryptedPayload = const Value.absent(),
    DateTime? updatedAt,
  }) => CachedProduct(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    sku: sku.present ? sku.value : this.sku,
    name: name ?? this.name,
    price: price ?? this.price,
    encryptedPayload: encryptedPayload.present
        ? encryptedPayload.value
        : this.encryptedPayload,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CachedProduct copyWithCompanion(CachedProductsCompanion data) {
    return CachedProduct(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      sku: data.sku.present ? data.sku.value : this.sku,
      name: data.name.present ? data.name.value : this.name,
      price: data.price.present ? data.price.value : this.price,
      encryptedPayload: data.encryptedPayload.present
          ? data.encryptedPayload.value
          : this.encryptedPayload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedProduct(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('sku: $sku, ')
          ..write('name: $name, ')
          ..write('price: $price, ')
          ..write('encryptedPayload: $encryptedPayload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, serverId, sku, name, price, encryptedPayload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedProduct &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.sku == this.sku &&
          other.name == this.name &&
          other.price == this.price &&
          other.encryptedPayload == this.encryptedPayload &&
          other.updatedAt == this.updatedAt);
}

class CachedProductsCompanion extends UpdateCompanion<CachedProduct> {
  final Value<String> id;
  final Value<String?> serverId;
  final Value<String?> sku;
  final Value<String> name;
  final Value<double> price;
  final Value<String?> encryptedPayload;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CachedProductsCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.sku = const Value.absent(),
    this.name = const Value.absent(),
    this.price = const Value.absent(),
    this.encryptedPayload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedProductsCompanion.insert({
    required String id,
    this.serverId = const Value.absent(),
    this.sku = const Value.absent(),
    required String name,
    this.price = const Value.absent(),
    this.encryptedPayload = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       updatedAt = Value(updatedAt);
  static Insertable<CachedProduct> custom({
    Expression<String>? id,
    Expression<String>? serverId,
    Expression<String>? sku,
    Expression<String>? name,
    Expression<double>? price,
    Expression<String>? encryptedPayload,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (sku != null) 'sku': sku,
      if (name != null) 'name': name,
      if (price != null) 'price': price,
      if (encryptedPayload != null) 'encrypted_payload': encryptedPayload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedProductsCompanion copyWith({
    Value<String>? id,
    Value<String?>? serverId,
    Value<String?>? sku,
    Value<String>? name,
    Value<double>? price,
    Value<String?>? encryptedPayload,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CachedProductsCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      price: price ?? this.price,
      encryptedPayload: encryptedPayload ?? this.encryptedPayload,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (sku.present) {
      map['sku'] = Variable<String>(sku.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (price.present) {
      map['price'] = Variable<double>(price.value);
    }
    if (encryptedPayload.present) {
      map['encrypted_payload'] = Variable<String>(encryptedPayload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedProductsCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('sku: $sku, ')
          ..write('name: $name, ')
          ..write('price: $price, ')
          ..write('encryptedPayload: $encryptedPayload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $OutboxItemsTable outboxItems = $OutboxItemsTable(this);
  late final $CachedProductsTable cachedProducts = $CachedProductsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    outboxItems,
    cachedProducts,
  ];
}

typedef $$OutboxItemsTableCreateCompanionBuilder =
    OutboxItemsCompanion Function({
      required String id,
      required String clientResourceId,
      required String idempotencyKey,
      required String method,
      required String path,
      required String bodyJson,
      required String status,
      Value<int> attemptCount,
      required DateTime createdAt,
      Value<DateTime?> nextAttemptAt,
      Value<String?> lastError,
      Value<String?> humanError,
      Value<int> rowid,
    });
typedef $$OutboxItemsTableUpdateCompanionBuilder =
    OutboxItemsCompanion Function({
      Value<String> id,
      Value<String> clientResourceId,
      Value<String> idempotencyKey,
      Value<String> method,
      Value<String> path,
      Value<String> bodyJson,
      Value<String> status,
      Value<int> attemptCount,
      Value<DateTime> createdAt,
      Value<DateTime?> nextAttemptAt,
      Value<String?> lastError,
      Value<String?> humanError,
      Value<int> rowid,
    });

class $$OutboxItemsTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxItemsTable> {
  $$OutboxItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientResourceId => $composableBuilder(
    column: $table.clientResourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyJson => $composableBuilder(
    column: $table.bodyJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get humanError => $composableBuilder(
    column: $table.humanError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxItemsTable> {
  $$OutboxItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientResourceId => $composableBuilder(
    column: $table.clientResourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyJson => $composableBuilder(
    column: $table.bodyJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get humanError => $composableBuilder(
    column: $table.humanError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxItemsTable> {
  $$OutboxItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientResourceId => $composableBuilder(
    column: $table.clientResourceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get bodyJson =>
      $composableBuilder(column: $table.bodyJson, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get humanError => $composableBuilder(
    column: $table.humanError,
    builder: (column) => column,
  );
}

class $$OutboxItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxItemsTable,
          OutboxItem,
          $$OutboxItemsTableFilterComposer,
          $$OutboxItemsTableOrderingComposer,
          $$OutboxItemsTableAnnotationComposer,
          $$OutboxItemsTableCreateCompanionBuilder,
          $$OutboxItemsTableUpdateCompanionBuilder,
          (
            OutboxItem,
            BaseReferences<_$AppDatabase, $OutboxItemsTable, OutboxItem>,
          ),
          OutboxItem,
          PrefetchHooks Function()
        > {
  $$OutboxItemsTableTableManager(_$AppDatabase db, $OutboxItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> clientResourceId = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> bodyJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> humanError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxItemsCompanion(
                id: id,
                clientResourceId: clientResourceId,
                idempotencyKey: idempotencyKey,
                method: method,
                path: path,
                bodyJson: bodyJson,
                status: status,
                attemptCount: attemptCount,
                createdAt: createdAt,
                nextAttemptAt: nextAttemptAt,
                lastError: lastError,
                humanError: humanError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String clientResourceId,
                required String idempotencyKey,
                required String method,
                required String path,
                required String bodyJson,
                required String status,
                Value<int> attemptCount = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> humanError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxItemsCompanion.insert(
                id: id,
                clientResourceId: clientResourceId,
                idempotencyKey: idempotencyKey,
                method: method,
                path: path,
                bodyJson: bodyJson,
                status: status,
                attemptCount: attemptCount,
                createdAt: createdAt,
                nextAttemptAt: nextAttemptAt,
                lastError: lastError,
                humanError: humanError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxItemsTable, OutboxItem>(table),
                  BaseReferences<_$AppDatabase, $OutboxItemsTable, OutboxItem>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxItemsTable,
      OutboxItem,
      $$OutboxItemsTableFilterComposer,
      $$OutboxItemsTableOrderingComposer,
      $$OutboxItemsTableAnnotationComposer,
      $$OutboxItemsTableCreateCompanionBuilder,
      $$OutboxItemsTableUpdateCompanionBuilder,
      (
        OutboxItem,
        BaseReferences<_$AppDatabase, $OutboxItemsTable, OutboxItem>,
      ),
      OutboxItem,
      PrefetchHooks Function()
    >;
typedef $$CachedProductsTableCreateCompanionBuilder =
    CachedProductsCompanion Function({
      required String id,
      Value<String?> serverId,
      Value<String?> sku,
      required String name,
      Value<double> price,
      Value<String?> encryptedPayload,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CachedProductsTableUpdateCompanionBuilder =
    CachedProductsCompanion Function({
      Value<String> id,
      Value<String?> serverId,
      Value<String?> sku,
      Value<String> name,
      Value<double> price,
      Value<String?> encryptedPayload,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CachedProductsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedProductsTable> {
  $$CachedProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sku => $composableBuilder(
    column: $table.sku,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedProductsTable> {
  $$CachedProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sku => $composableBuilder(
    column: $table.sku,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedProductsTable> {
  $$CachedProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get sku =>
      $composableBuilder(column: $table.sku, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<String> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CachedProductsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedProductsTable,
          CachedProduct,
          $$CachedProductsTableFilterComposer,
          $$CachedProductsTableOrderingComposer,
          $$CachedProductsTableAnnotationComposer,
          $$CachedProductsTableCreateCompanionBuilder,
          $$CachedProductsTableUpdateCompanionBuilder,
          (
            CachedProduct,
            BaseReferences<_$AppDatabase, $CachedProductsTable, CachedProduct>,
          ),
          CachedProduct,
          PrefetchHooks Function()
        > {
  $$CachedProductsTableTableManager(
    _$AppDatabase db,
    $CachedProductsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String?> sku = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> price = const Value.absent(),
                Value<String?> encryptedPayload = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedProductsCompanion(
                id: id,
                serverId: serverId,
                sku: sku,
                name: name,
                price: price,
                encryptedPayload: encryptedPayload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> serverId = const Value.absent(),
                Value<String?> sku = const Value.absent(),
                required String name,
                Value<double> price = const Value.absent(),
                Value<String?> encryptedPayload = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedProductsCompanion.insert(
                id: id,
                serverId: serverId,
                sku: sku,
                name: name,
                price: price,
                encryptedPayload: encryptedPayload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedProductsTable, CachedProduct>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CachedProductsTable,
                    CachedProduct
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedProductsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedProductsTable,
      CachedProduct,
      $$CachedProductsTableFilterComposer,
      $$CachedProductsTableOrderingComposer,
      $$CachedProductsTableAnnotationComposer,
      $$CachedProductsTableCreateCompanionBuilder,
      $$CachedProductsTableUpdateCompanionBuilder,
      (
        CachedProduct,
        BaseReferences<_$AppDatabase, $CachedProductsTable, CachedProduct>,
      ),
      CachedProduct,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$OutboxItemsTableTableManager get outboxItems =>
      $$OutboxItemsTableTableManager(_db, _db.outboxItems);
  $$CachedProductsTableTableManager get cachedProducts =>
      $$CachedProductsTableTableManager(_db, _db.cachedProducts);
}
