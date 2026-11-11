import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error_message.dart';
import '../../../core/result/result.dart';
import '../domain/customer.dart';
import '../domain/kenya_admin_units.dart';

class ReceiveWalletPaymentResult {
  const ReceiveWalletPaymentResult({
    required this.walletBalance,
    this.transactionId,
    this.pendingApproval = false,
    this.message,
  });

  final double walletBalance;
  final int? transactionId;
  final bool pendingApproval;
  final String? message;

  factory ReceiveWalletPaymentResult.fromJson(Map<String, dynamic> json) {
    double asDouble(Object? v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }

    final tx = json['transaction'];
    return ReceiveWalletPaymentResult(
      walletBalance: asDouble(json['wallet_balance']),
      transactionId: tx is Map ? (tx['id'] as num?)?.toInt() : null,
      pendingApproval: json['pending_change'] != null,
      message: json['message']?.toString(),
    );
  }
}

/// One page from `GET /sales/customers/` (DRF page-number pagination).
class CustomerPage {
  const CustomerPage({
    required this.results,
    required this.count,
    required this.page,
    required this.pageSize,
    required this.hasNext,
  });

  final List<CustomerSummary> results;
  final int count;
  final int page;
  final int pageSize;
  final bool hasNext;
}

class CustomersApi {
  CustomersApi(this._client);

  final ApiClient _client;

  /// Paginated customer directory. Backend default page size is 10.
  ///
  /// Location filters (`county` / `sub_county` / `ward` / `location_status`)
  /// match the web Customers list and Kenya admin catalog.
  Future<Result<CustomerPage>> list({
    String search = '',
    int page = 1,
    int pageSize = 25,
    String engagementTier = '',
    String buyerSegment = '',
    String county = '',
    String subCounty = '',
    String ward = '',
    String locationStatus = '',
  }) async {
    final params = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
    };
    final q = search.trim();
    if (q.isNotEmpty) params['search'] = q;
    final tier = engagementTier.trim();
    if (tier.isNotEmpty) params['engagement_tier'] = tier;
    final segment = buyerSegment.trim();
    if (segment.isNotEmpty) params['buyer_segment'] = segment;
    final countyQ = county.trim();
    if (countyQ.isNotEmpty) params['county'] = countyQ;
    final subQ = subCounty.trim();
    if (subQ.isNotEmpty) params['sub_county'] = subQ;
    final wardQ = ward.trim();
    if (wardQ.isNotEmpty) params['ward'] = wardQ;
    final locStatus = locationStatus.trim();
    if (locStatus.isNotEmpty) params['location_status'] = locStatus;
    final query = params.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
    final response = await _client.get('sales/customers/?$query');
    if (response.isFailure) {
      final f = response as Failure;
      return Failure(f.error, f.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(CustomersApiException(_safeError(res.body)));
    }
    return Success(_parseCustomerPage(res.body, page: page, pageSize: pageSize));
  }

  static CustomerPage _parseCustomerPage(
    String body, {
    required int page,
    required int pageSize,
  }) {
    final decoded = jsonDecode(body);
    if (decoded is List) {
      final results = [
        for (final item in decoded)
          if (item is Map)
            CustomerSummary.fromJson(Map<String, dynamic>.from(item)),
      ];
      return CustomerPage(
        results: results,
        count: results.length,
        page: page,
        pageSize: pageSize,
        hasNext: false,
      );
    }
    if (decoded is! Map) {
      return CustomerPage(
        results: const [],
        count: 0,
        page: page,
        pageSize: pageSize,
        hasNext: false,
      );
    }
    final map = Map<String, dynamic>.from(decoded);
    final raw = map['results'];
    final results = <CustomerSummary>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          results.add(CustomerSummary.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    final count = (map['count'] as num?)?.toInt() ?? results.length;
    final hasNext = map['next'] != null && results.isNotEmpty;
    return CustomerPage(
      results: results,
      count: count,
      page: page,
      pageSize: pageSize,
      hasNext: hasNext,
    );
  }

  Future<Result<CustomerDetail>> detail(int id) async {
    final response = await _client.get('sales/customers/$id/detail/');
    if (response.isFailure) {
      final f = response as Failure;
      return Failure(f.error, f.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(CustomersApiException(_safeError(res.body)));
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      return Failure(CustomersApiException('Unexpected customer detail.'));
    }
    return Success(
      CustomerDetail.fromDetailJson(Map<String, dynamic>.from(decoded)),
    );
  }

  Future<Result<KenyaAdminUnits>> fetchKenyaLocations() async {
    final response = await _client.get('sales/customers/kenya-locations/');
    if (response.isFailure) {
      final f = response as Failure;
      return Failure(f.error, f.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(CustomersApiException(_safeError(res.body)));
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      return Failure(CustomersApiException('Unexpected location data.'));
    }
    return Success(
      KenyaAdminUnits.fromJson(Map<String, dynamic>.from(decoded)),
    );
  }

  Future<Result<CustomerSummary>> create(CustomerDraft draft) async {
    final first = await _parseCustomerWrite(
      await _client.post('sales/customers/', body: draft.toJson()),
    );
    if (first.isSuccess || !draft.hasLocationPing) return first;
    // Older servers rolled back the whole create when default site-pin sync
    // failed. Retry once without GPS so the duka still registers.
    return _parseCustomerWrite(
      await _client.post(
        'sales/customers/',
        body: draft.withoutLocationPing().toJson(),
      ),
    );
  }

  Future<Result<CustomerSummary>> update(int id, CustomerDraft draft) async {
    final first = await _parseCustomerWrite(
      await _client.patch('sales/customers/$id/', body: draft.toJson()),
    );
    if (first.isSuccess || !draft.hasLocationPing) return first;
    return _parseCustomerWrite(
      await _client.patch(
        'sales/customers/$id/',
        body: draft.withoutLocationPing().toJson(),
      ),
    );
  }

  Future<Result<CustomerSummary>> _parseCustomerWrite(
    Result<http.Response> response,
  ) async {
    if (response.isFailure) {
      final f = response as Failure<http.Response>;
      return Failure(f.error, f.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(
        CustomersApiException(
          _safeError(
            res.body,
            statusCode: res.statusCode,
            fallback:
                'Could not save this duka. Check the details and try again.',
          ),
        ),
      );
    }
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) {
        return Failure(CustomersApiException('Unexpected customer response.'));
      }
      return Success(
        CustomerSummary.fromJson(Map<String, dynamic>.from(decoded)),
      );
    } on Object catch (e) {
      return Failure(
        CustomersApiException(
          'Saved on server but could not read the response: $e',
        ),
      );
    }
  }

  Future<Result<ReceiveWalletPaymentResult>> receiveWalletPayment({
    required int customerId,
    required double amount,
    required String paymentMethod,
    String reference = '',
    String notes = '',
    String payerName = '',
    String payerPhone = '',
    String mpesaDestination = '',
    String paymentDate = '',
    List<int>? receiptImageBytes,
    String receiptFileName = 'mpesa_receipt.jpg',
    String receiptContentType = 'image/jpeg',
    required String idempotencyKey,
  }) async {
    final path = 'sales/customers/$customerId/receive-wallet-payment/';
    final Result<http.Response> response;
    if (receiptImageBytes != null && receiptImageBytes.isNotEmpty) {
      response = await _client.postMultipart(
        path,
        fields: {
          'amount': amount.toString(),
          'payment_method': paymentMethod,
          if (reference.trim().isNotEmpty) 'reference': reference.trim(),
          if (notes.trim().isNotEmpty) 'notes': notes.trim(),
          if (payerName.trim().isNotEmpty) 'payer_name': payerName.trim(),
          if (payerPhone.trim().isNotEmpty) 'payer_phone': payerPhone.trim(),
          if (mpesaDestination.trim().isNotEmpty)
            'mpesa_destination': mpesaDestination.trim(),
          if (paymentDate.trim().isNotEmpty) 'payment_date': paymentDate.trim(),
        },
        fileField: 'receipt_image',
        fileBytes: receiptImageBytes,
        fileName: receiptFileName,
        contentType: receiptContentType,
        idempotencyKey: idempotencyKey,
      );
    } else {
      response = await _client.post(
        path,
        body: {
          'amount': amount,
          'payment_method': paymentMethod,
          if (reference.trim().isNotEmpty) 'reference': reference.trim(),
          if (notes.trim().isNotEmpty) 'notes': notes.trim(),
          if (payerName.trim().isNotEmpty) 'payer_name': payerName.trim(),
          if (payerPhone.trim().isNotEmpty) 'payer_phone': payerPhone.trim(),
          if (mpesaDestination.trim().isNotEmpty)
            'mpesa_destination': mpesaDestination.trim(),
          if (paymentDate.trim().isNotEmpty) 'payment_date': paymentDate.trim(),
        },
        idempotencyKey: idempotencyKey,
      );
    }
    if (response.isFailure) {
      final f = response as Failure;
      return Failure(f.error, f.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(
        CustomersApiException(
          _safePaymentError(res.body, statusCode: res.statusCode),
        ),
      );
    }
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) {
        return Failure(CustomersApiException('Unexpected payment response.'));
      }
      return Success(
        ReceiveWalletPaymentResult.fromJson(Map<String, dynamic>.from(decoded)),
      );
    } on Object catch (e) {
      return Failure(
        CustomersApiException(
          'Payment may have been recorded but the response could not be read: $e',
        ),
      );
    }
  }

  Future<Result<CustomersModuleSettings>> loadSettings() async {
    try {
      final response = await _client.get('settings/customers/');
      if (response.isFailure) {
        return const Success(CustomersModuleSettings());
      }
      final res = response.getOrThrow();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return const Success(CustomersModuleSettings());
      }
      final decoded = jsonDecode(res.body);
      if (decoded is Map) {
        return Success(
          CustomersModuleSettings.fromJson(Map<String, dynamic>.from(decoded)),
        );
      }
      return const Success(CustomersModuleSettings());
    } on Object {
      return const Success(CustomersModuleSettings());
    }
  }

  static String _safeError(
    String body, {
    int? statusCode,
    String fallback = 'Could not save this duka. Check the details and try again.',
  }) {
    final parsed = apiErrorMessage(body, fallback: '');
    if (parsed.isNotEmpty) return parsed;
    if (statusCode == 401) {
      return 'Please sign in again, then save the duka.';
    }
    if (statusCode == 403) {
      return 'You do not have permission to save this duka.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'Server error while saving this duka. Try again in a moment.';
    }
    if (statusCode != null) {
      return '$fallback (code $statusCode)';
    }
    return fallback;
  }

  /// Payment failures used to fall through to the duka-save fallback text.
  static String _safePaymentError(String body, {int? statusCode}) {
    final parsed = apiErrorMessage(body, fallback: '');
    if (parsed.isNotEmpty) return parsed;
    if (statusCode == 401) {
      return 'Please sign in again, then record the payment.';
    }
    if (statusCode == 403) {
      return 'You do not have permission to record this payment.';
    }
    if (statusCode == 413) {
      return 'Receipt photo is too large for the server. '
          'Pick a smaller screenshot and try again.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'Server error while recording this payment. Try again in a moment.';
    }
    if (statusCode != null) {
      return 'Could not record this payment. Check the details and try again. '
          '(code $statusCode)';
    }
    return 'Could not record this payment. Check the details and try again.';
  }
}

class CustomersApiException implements Exception {
  CustomersApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
