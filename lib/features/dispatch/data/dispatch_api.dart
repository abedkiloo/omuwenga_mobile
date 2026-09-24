import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../../field_orders/domain/field_order.dart';

class DispatchApiException implements Exception {
  DispatchApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DeliveryDriverOption {
  const DeliveryDriverOption({
    required this.id,
    required this.displayName,
    this.username = '',
    this.roleName = '',
  });

  final int id;
  final String displayName;
  final String username;
  final String roleName;

  String get listLabel {
    final role = roleName.trim();
    if (role.isEmpty) return displayName;
    return '$displayName · $role';
  }

  factory DeliveryDriverOption.fromJson(Map<String, dynamic> json) {
    return DeliveryDriverOption(
      id: (json['id'] as num).toInt(),
      displayName: (json['display_name'] ?? json['username'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      roleName: (json['role_name'] ?? '').toString(),
    );
  }
}

class CreatedDeliveryDriver extends DeliveryDriverOption {
  const CreatedDeliveryDriver({
    required super.id,
    required super.displayName,
    super.username = '',
    super.roleName = '',
    this.phoneNumber = '',
    this.temporaryPassword = '',
  });

  final String phoneNumber;
  final String temporaryPassword;

  factory CreatedDeliveryDriver.fromJson(Map<String, dynamic> json) {
    return CreatedDeliveryDriver(
      id: (json['id'] as num).toInt(),
      displayName: (json['display_name'] ?? json['username'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      roleName: (json['role_name'] ?? '').toString(),
      phoneNumber: (json['phone_number'] ?? '').toString(),
      temporaryPassword: (json['temporary_password'] ?? '').toString(),
    );
  }
}

class DispatchApi {
  DispatchApi(this._client);
  final ApiClient _client;

  Future<Result<List<FieldOrderSummary>>> queue() async {
    final res = await _client.get('dispatch/queue/');
    if (res.isFailure) return Failure((res as Failure).error);
    final response = res.getOrThrow();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Failure(
        DispatchApiException('Queue failed (${response.statusCode})'),
      );
    }
    try {
      final data = jsonDecode(response.body);
      if (data is! List) {
        return Failure(DispatchApiException('Invalid queue payload'));
      }
      return Success([
        for (final row in data)
          if (row is Map)
            FieldOrderSummary.fromJson(Map<String, dynamic>.from(row)),
      ]);
    } on Object catch (e, st) {
      return Failure(e, st);
    }
  }

  Future<Result<List<DeliveryDriverOption>>> drivers() async {
    final res = await _client.get('dispatch/drivers/');
    if (res.isFailure) return Failure((res as Failure).error);
    final response = res.getOrThrow();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Failure(
        DispatchApiException('Drivers failed (${response.statusCode})'),
      );
    }
    try {
      final data = jsonDecode(response.body);
      if (data is! List) {
        return Failure(DispatchApiException('Invalid drivers payload'));
      }
      return Success([
        for (final row in data)
          if (row is Map)
            DeliveryDriverOption.fromJson(Map<String, dynamic>.from(row)),
      ]);
    } on Object catch (e, st) {
      return Failure(e, st);
    }
  }

  Future<Result<CreatedDeliveryDriver>> createDriver({
    required String displayName,
    required String phone,
  }) async {
    final res = await _client.post(
      'dispatch/drivers/',
      body: {
        'display_name': displayName.trim(),
        'phone': phone.trim(),
      },
    );
    if (res.isFailure) return Failure((res as Failure).error);
    final response = res.getOrThrow();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Failure(
        DispatchApiException(_driverError(response.body, response.statusCode)),
      );
    }
    try {
      final data = jsonDecode(response.body);
      if (data is! Map) {
        return Failure(DispatchApiException('Invalid driver payload'));
      }
      return Success(
        CreatedDeliveryDriver.fromJson(Map<String, dynamic>.from(data)),
      );
    } on Object catch (e, st) {
      return Failure(e, st);
    }
  }

  String _driverError(String body, int statusCode) {
    try {
      final data = jsonDecode(body);
      if (data is Map) {
        if (data['display_name'] is List && data['display_name'].isNotEmpty) {
          return data['display_name'].first.toString();
        }
        if (data['phone'] is List && data['phone'].isNotEmpty) {
          return data['phone'].first.toString();
        }
        if (data['detail'] != null) return data['detail'].toString();
        if (data['error'] != null) return data['error'].toString();
      }
    } on Object {
      /* ignore */
    }
    return 'Could not add driver ($statusCode)';
  }

  Future<Result<FieldOrderSummary>> pack(int orderId) async {
    final res = await _client.post('dispatch/field-orders/$orderId/pack/');
    return _parse(res, 'Pack failed');
  }

  Future<Result<FieldOrderSummary>> assign({
    required int orderId,
    required int deliveryDriverId,
  }) async {
    final res = await _client.post(
      'dispatch/field-orders/$orderId/assign/',
      body: {'delivery_agent_id': deliveryDriverId},
    );
    return _parse(res, 'Assign failed');
  }

  Future<Result<FieldOrderSummary>> _parse(
    Result responseResult,
    String label,
  ) async {
    if (responseResult.isFailure) {
      return Failure((responseResult as Failure).error);
    }
    final response = responseResult.getOrThrow();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Failure(DispatchApiException('$label (${response.statusCode})'));
    }
    try {
      final data = jsonDecode(response.body);
      if (data is! Map) {
        return Failure(DispatchApiException('Invalid order payload'));
      }
      return Success(
        FieldOrderSummary.fromJson(Map<String, dynamic>.from(data)),
      );
    } on Object catch (e, st) {
      return Failure(e, st);
    }
  }
}
