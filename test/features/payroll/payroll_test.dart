import 'package:completebyte_pos_mobile/features/auth/domain/permission_set.dart';
import 'package:completebyte_pos_mobile/features/payroll/domain/payroll.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _payJson() {
  return {
    'linked': true,
    'employee': {
      'id': 12,
      'employee_id': 'EMP-9',
      'name': 'Ann Cash',
      'position': 'Sales Personnel',
      'department': 'sales',
    },
    'effective_basic': '20000.00',
    'basic_source': 'employee.salary',
    'estimated_gross': '22500.00',
    'estimated_deductions': '0.00',
    'estimated_net': '22500.00',
    'currency': 'KES',
    'role_name': 'Sales',
    'package_name': 'Sales package',
    'inherits_package': true,
    'earnings': [
      {
        'code': 'BASIC',
        'name': 'Basic salary',
        'kind': 'earning',
        'amount': '20000.00',
        'source': 'employee.salary',
      },
      {
        'code': 'ALLOWANCE_TRANSPORT',
        'name': 'Transport allowance',
        'kind': 'earning',
        'amount': '2500.00',
        'source': 'role_package',
      },
    ],
    'deductions': [],
  };
}

void main() {
  test('MyCurrentPay parses estimate and lines', () {
    final pay = MyCurrentPay.fromJson(_payJson());
    expect(pay.linked, isTrue);
    expect(pay.staffCode, 'EMP-9');
    expect(pay.name, 'Ann Cash');
    expect(pay.effectiveBasic, 20000);
    expect(pay.estimatedGross, 22500);
    expect(pay.estimatedNet, 22500);
    expect(pay.packageName, 'Sales package');
    expect(pay.inheritsPackage, isTrue);
    expect(pay.earnings, hasLength(2));
    expect(pay.earnings.first.code, 'BASIC');
    expect(pay.earnings.last.amount, 2500);
  });

  test('unlinked pay payload', () {
    final pay = MyCurrentPay.fromJson({
      'linked': false,
      'detail': 'No employee record linked to your account email.',
    });
    expect(pay.linked, isFalse);
    expect(pay.detail, contains('No employee'));
    expect(pay.earnings, isEmpty);
  });

  test('MyPayslipSummary parses list row', () {
    final slip = MyPayslipSummary.fromJson({
      'id': 44,
      'period': '2026-09',
      'year': 2026,
      'month': 9,
      'gross_pay': '22500.00',
      'total_deductions': '1500.00',
      'net_pay': '21000.00',
      'currency': 'KES',
      'employee_name_snapshot': 'Ann Cash',
      'employee_id_snapshot': 'EMP-9',
      'filename': 'Ann_Cash_September_2026_EMP-9.pdf',
      'run_status': 'locked',
    });
    expect(slip.id, 44);
    expect(slip.period, '2026-09');
    expect(slip.netPay, 21000);
    expect(slip.grossPay, 22500);
    expect(slip.downloadFilename, 'Ann_Cash_September_2026_EMP-9.pdf');
  });

  test('payslip download name builds from name month year and staff code', () {
    final slip = MyPayslipSummary.fromJson({
      'id': 1,
      'period': '2026-09',
      'year': 2026,
      'month': 9,
      'gross_pay': '0',
      'total_deductions': '0',
      'net_pay': '0',
      'employee_name_snapshot': 'Sam Staff',
      'employee_id_snapshot': 'SLIP-1',
    });
    expect(slip.downloadFilename, 'Sam_Staff_September_2026_SLIP-1.pdf');
  });

  test('canViewPayroll from view_own or view', () {
    expect(
      PermissionSet([
        const PermissionGrant(module: 'payroll', action: 'view_own'),
      ]).canViewPayroll,
      isTrue,
    );
    expect(
      PermissionSet([
        const PermissionGrant(module: 'payroll', action: 'view'),
      ]).canViewPayroll,
      isTrue,
    );
    expect(PermissionSet(const []).canViewPayroll, isFalse);
  });
}
