import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/payroll.dart';

/// Full-screen preview of a payslip PDF generated on request (not stored).
class PayslipPreviewPage extends StatelessWidget {
  const PayslipPreviewPage({
    super.key,
    required this.slip,
    required this.bytes,
  });

  final MyPayslipSummary slip;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(slip.period.isEmpty ? 'Payslip' : slip.period),
        actions: [
          IconButton(
            key: Key('payslip_share_${slip.id}'),
            tooltip: 'Share or print',
            icon: const Icon(Icons.share_outlined),
            onPressed: () async {
              await Printing.sharePdf(
                bytes: bytes,
                filename: slip.downloadFilename,
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              [
                if (slip.employeeName.isNotEmpty) slip.employeeName,
                if (slip.employeeStaffCode.isNotEmpty) slip.employeeStaffCode,
              ].join(' · '),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Generated on request — not stored on the server.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: PdfPreview(
              build: (_) async => bytes,
              pdfFileName: slip.downloadFilename,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              allowPrinting: true,
              allowSharing: true,
            ),
          ),
        ],
      ),
    );
  }
}
