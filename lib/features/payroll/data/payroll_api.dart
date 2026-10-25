import 'dart:convert';
import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../domain/payroll.dart';

class PayrollApiException implements Exception {
  PayrollApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PayrollApi {
  PayrollApi(this._client);
  final ApiClient _client;

  Future<Result<MyCurrentPay>> myPay() async {
    final res = await _client.get('payroll/me/pay/');
    if (res.isFailure) return Failure((res as Failure).error);
    final response = res.getOrThrow();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Failure(
        PayrollApiException('Load pay failed (${response.statusCode})'),
      );
    }
    try {
      final data = jsonDecode(response.body);
      if (data is! Map) {
        return Failure(PayrollApiException('Invalid pay payload'));
      }
      return Success(MyCurrentPay.fromJson(Map<String, dynamic>.from(data)));
    } on Object catch (e, st) {
      return Failure(e, st);
    }
  }

  Future<Result<List<MyPayslipSummary>>> myPayslips() async {
    final res = await _client.get('payroll/me/payslips/');
    if (res.isFailure) return Failure((res as Failure).error);
    final response = res.getOrThrow();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Failure(
        PayrollApiException('Load payslips failed (${response.statusCode})'),
      );
    }
    try {
      final data = jsonDecode(response.body);
      final list = data is List
          ? data
          : (data is Map && data['results'] is List)
              ? data['results'] as List
              : const [];
      return Success([
        for (final item in list)
          if (item is Map)
            MyPayslipSummary.fromJson(Map<String, dynamic>.from(item)),
      ]);
    } on Object catch (e, st) {
      return Failure(e, st);
    }
  }

  Future<Result<Uint8List>> myPayslipPdf(int payslipId) async {
    final res = await _client.get('payroll/me/payslips/$payslipId/pdf/');
    if (res.isFailure) return Failure((res as Failure).error);
    final response = res.getOrThrow();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Failure(
        PayrollApiException('Download payslip failed (${response.statusCode})'),
      );
    }
    final bytes = response.bodyBytes;
    if (bytes.length < 5 ||
        String.fromCharCodes(bytes.take(4)) != '%PDF') {
      return Failure(PayrollApiException('Invalid PDF response'));
    }
    return Success(Uint8List.fromList(bytes));
  }
}
