double _asDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

class PayLine {
  const PayLine({
    required this.code,
    required this.name,
    required this.kind,
    required this.amount,
    this.source = '',
  });

  final String code;
  final String name;
  final String kind;
  final double amount;
  final String source;

  factory PayLine.fromJson(Map<String, dynamic> json) {
    return PayLine(
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      amount: _asDouble(json['amount']),
      source: (json['source'] ?? '').toString(),
    );
  }
}

class MyCurrentPay {
  const MyCurrentPay({
    required this.linked,
    this.employeeId = '',
    this.staffCode = '',
    this.name = '',
    this.position = '',
    this.department = '',
    this.effectiveBasic = 0,
    this.basicSource = '',
    this.estimatedGross = 0,
    this.estimatedDeductions = 0,
    this.estimatedNet = 0,
    this.currency = 'KES',
    this.roleName,
    this.packageName,
    this.inheritsPackage = false,
    this.earnings = const [],
    this.deductions = const [],
    this.detail,
  });

  final bool linked;
  final String employeeId;
  final String staffCode;
  final String name;
  final String position;
  final String department;
  final double effectiveBasic;
  final String basicSource;
  final double estimatedGross;
  final double estimatedDeductions;
  final double estimatedNet;
  final String currency;
  final String? roleName;
  final String? packageName;
  final bool inheritsPackage;
  final List<PayLine> earnings;
  final List<PayLine> deductions;
  final String? detail;

  factory MyCurrentPay.fromJson(Map<String, dynamic> json) {
    final emp = json['employee'];
    final empMap = emp is Map ? Map<String, dynamic>.from(emp) : const <String, dynamic>{};
    List<PayLine> lines(dynamic raw) {
      if (raw is! List) return const [];
      return [
        for (final item in raw)
          if (item is Map)
            PayLine.fromJson(Map<String, dynamic>.from(item)),
      ];
    }

    return MyCurrentPay(
      linked: json['linked'] == true,
      employeeId: (empMap['id'] ?? '').toString(),
      staffCode: (empMap['employee_id'] ?? '').toString(),
      name: (empMap['name'] ?? '').toString(),
      position: (empMap['position'] ?? '').toString(),
      department: (empMap['department'] ?? '').toString(),
      effectiveBasic: _asDouble(json['effective_basic']),
      basicSource: (json['basic_source'] ?? '').toString(),
      estimatedGross: _asDouble(json['estimated_gross']),
      estimatedDeductions: _asDouble(json['estimated_deductions']),
      estimatedNet: _asDouble(json['estimated_net']),
      currency: (json['currency'] ?? 'KES').toString(),
      roleName: json['role_name']?.toString(),
      packageName: json['package_name']?.toString(),
      inheritsPackage: json['inherits_package'] == true,
      earnings: lines(json['earnings']),
      deductions: lines(json['deductions']),
      detail: json['detail']?.toString(),
    );
  }
}

class MyPayslipSummary {
  const MyPayslipSummary({
    required this.id,
    required this.period,
    required this.grossPay,
    required this.totalDeductions,
    required this.netPay,
    this.currency = 'KES',
    this.employeeName = '',
    this.employeeStaffCode = '',
    this.year = 0,
    this.month = 0,
    this.filename = '',
    this.runStatus = '',
  });

  final int id;
  final String period;
  final double grossPay;
  final double totalDeductions;
  final double netPay;
  final String currency;
  final String employeeName;
  final String employeeStaffCode;
  final int year;
  final int month;
  final String filename;
  final String runStatus;

  static const _monthNames = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// PersonName_Month_Year_EmployeeID.pdf (employee ID omitted when blank).
  String get downloadFilename {
    if (filename.trim().isNotEmpty) return filename.trim();
    final monthName =
        (month >= 1 && month <= 12) ? _monthNames[month] : 'Month';
    final yearLabel = year > 0 ? '$year' : 'Year';
    final parts = <String>[
      if (employeeName.trim().isNotEmpty) employeeName.trim() else 'Employee',
      monthName,
      yearLabel,
      if (employeeStaffCode.trim().isNotEmpty) employeeStaffCode.trim(),
    ];
    final safe = parts
        .join('_')
        .replaceAll(RegExp(r'[^\w.\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^[._]+|[._]+$'), '');
    return '${safe.isEmpty ? 'payslip' : safe}.pdf';
  }

  factory MyPayslipSummary.fromJson(Map<String, dynamic> json) {
    return MyPayslipSummary(
      id: int.tryParse('${json['id']}') ?? 0,
      period: (json['period'] ?? '').toString(),
      grossPay: _asDouble(json['gross_pay']),
      totalDeductions: _asDouble(json['total_deductions']),
      netPay: _asDouble(json['net_pay']),
      currency: (json['currency'] ?? 'KES').toString(),
      employeeName: (json['employee_name_snapshot'] ?? '').toString(),
      employeeStaffCode: (json['employee_id_snapshot'] ?? '').toString(),
      year: int.tryParse('${json['year']}') ?? 0,
      month: int.tryParse('${json['month']}') ?? 0,
      filename: (json['filename'] ?? '').toString(),
      runStatus: (json['run_status'] ?? '').toString(),
    );
  }
}
