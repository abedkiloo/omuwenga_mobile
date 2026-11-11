import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/barcode_scan.dart';

/// Retail symbologies for phone-camera POS (1D + QR / Data Matrix).
///
/// Matches common shelf labels, printed Code128/SKU labels, and product QR.
const List<BarcodeFormat> kPosRetailBarcodeFormats = [
  BarcodeFormat.ean13,
  BarcodeFormat.ean8,
  BarcodeFormat.upcA,
  BarcodeFormat.upcE,
  BarcodeFormat.code128,
  BarcodeFormat.code39,
  BarcodeFormat.code93,
  BarcodeFormat.codabar,
  BarcodeFormat.itf14,
  BarcodeFormat.itf2of5,
  BarcodeFormat.qrCode,
  BarcodeFormat.dataMatrix,
];

/// Full-screen continuous barcode + QR scanner for native Retail POS.
///
/// Stays open so cashiers can sweep multiple items (industry continuous scan).
/// Each decode calls [onScan]; Close / Done pops the route.
/// Bluetooth HID guns do not use this page — they type into the search field.
class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({
    super.key,
    required this.onScan,
  });

  /// Lookup + add-to-cart for one decoded code. May be called repeatedly.
  ///
  /// Return [PosScanFeedback.ignored] for duplicate/busy; otherwise a short
  /// message shown on the scanner chrome.
  final Future<PosScanFeedback> Function(String code) onScan;

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 1200,
    facing: CameraFacing.back,
    torchEnabled: false,
    autoTorch: true,
    autoZoom: true,
    formats: kPosRetailBarcodeFormats,
  );

  final TextEditingController _manual = TextEditingController();
  final GlobalKey _previewKey = GlobalKey();

  bool _busy = false;
  String? _error;
  PosScanFeedback? _lastFeedback;
  int _addedCount = 0;
  Rect _scanWindow = Rect.zero;

  @override
  void dispose() {
    _manual.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _updateScanWindow(BoxConstraints constraints) {
    final size = constraints.biggest;
    if (size.isEmpty) return;
    // Square reticle: works for 1D barcodes and QR / Data Matrix.
    final side = (size.shortestSide * 0.72).clamp(200.0, 320.0);
    final next = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.36),
      width: side,
      height: side,
    );
    if ((next.left - _scanWindow.left).abs() > 1 ||
        (next.top - _scanWindow.top).abs() > 1 ||
        (next.width - _scanWindow.width).abs() > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _scanWindow = next);
      });
    }
  }

  Future<void> _playSuccessCue() async {
    await HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
  }

  Future<void> _playErrorCue() async {
    await HapticFeedback.heavyImpact();
  }

  Future<void> _handleCode(String raw) async {
    if (_busy || !mounted) return;
    final code = extractProductScanCode(raw);
    if (code.isEmpty) return;

    setState(() => _busy = true);
    try {
      final feedback = await widget.onScan(code);
      if (!mounted) return;
      if (feedback.isIgnored) return;

      setState(() {
        _lastFeedback = feedback;
        if (feedback.ok) _addedCount += 1;
      });
      if (feedback.ok) {
        await _playSuccessCue();
      } else {
        await _playErrorCue();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || !mounted) return;
    String raw = '';
    for (final barcode in capture.barcodes) {
      final candidate = normalizeScanCode(
        barcode.rawValue ?? barcode.displayValue,
      );
      if (candidate.isNotEmpty) {
        raw = candidate;
        break;
      }
    }
    if (raw.isEmpty) return;
    await _handleCode(raw);
  }

  Future<void> _submitManual() async {
    await _handleCode(_manual.text);
    if (!mounted) return;
    if (_lastFeedback?.ok == true) {
      _manual.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedback = _lastFeedback;
    final feedbackColor = feedback == null
        ? Colors.white70
        : (feedback.ok ? const Color(0xFF7CFFB2) : const Color(0xFFFFB4A8));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan barcode / QR'),
        actions: [
          IconButton(
            tooltip: 'Toggle torch',
            onPressed: () => _controller.toggleTorch(),
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, _) {
                final on = state.torchState == TorchState.on;
                return Icon(on ? Icons.flash_on : Icons.flash_off);
              },
            ),
          ),
          TextButton(
            key: const Key('barcode_scanner_done'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              _addedCount > 0 ? 'Done ($_addedCount)' : 'Done',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _updateScanWindow(constraints);
                return Stack(
                  fit: StackFit.expand,
                  key: _previewKey,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      scanWindow: _scanWindow == Rect.zero ? null : _scanWindow,
                      tapToFocus: true,
                      onDetect: _onDetect,
                      overlayBuilder: (context, box) {
                        if (_scanWindow == Rect.zero) {
                          return const SizedBox.shrink();
                        }
                        return ScanWindowOverlay(
                          controller: _controller,
                          scanWindow: _scanWindow,
                          borderColor: AppColors.primary,
                          borderRadius: BorderRadius.circular(16),
                          borderWidth: 3,
                          color: const Color(0x99000000),
                        );
                      },
                      errorBuilder: (context, error) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() {
                            _error = error.errorDetails?.message ??
                                'Camera unavailable. Allow camera permission or type the code below.';
                          });
                        });
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              error.errorDetails?.message ??
                                  'Camera unavailable. Allow camera permission.',
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),
                    if (_busy)
                      const Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Container(
            width: double.infinity,
            color: Colors.black87,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _error ??
                      (feedback?.message.isNotEmpty == true
                          ? feedback!.message
                          : 'Point at a barcode or QR. Keep scanning — tap Done when finished.'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _error != null ? Colors.orangeAccent : feedbackColor,
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('barcode_manual_entry'),
                        controller: _manual,
                        enabled: !_busy,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: AppColors.primary,
                        keyboardType: TextInputType.visiblePassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submitManual(),
                        decoration: InputDecoration(
                          hintText: 'Type barcode / QR / SKU',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                          filled: true,
                          fillColor: Colors.white12,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const Key('barcode_manual_submit'),
                      onPressed: _busy ? null : _submitManual,
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens continuous [BarcodeScannerPage] for Retail POS selling.
///
/// [onScan] is invoked for every successful decode / manual entry until the
/// cashier taps Done. Does not return a code — cart updates happen via [onScan].
Future<void> openBarcodeScanner(
  BuildContext context, {
  required Future<PosScanFeedback> Function(String code) onScan,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => BarcodeScannerPage(onScan: onScan),
    ),
  );
}
