import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/qr_attendance_service.dart';
import '../../theme/app_theme.dart';

/// Members scan the rehearsal QR code from here.
class QrCheckInScreen extends StatefulWidget {
  const QrCheckInScreen({super.key});

  @override
  State<QrCheckInScreen> createState() => _QrCheckInScreenState();
}

class _QrCheckInScreenState extends State<QrCheckInScreen> {
  final MobileScannerController _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _submitting = false;
  bool _done = false;
  String? _status; // last error / message

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<({double? lat, double? lng})> _tryLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        final asked = await Geolocator.requestPermission();
        if (asked == LocationPermission.denied ||
            asked == LocationPermission.deniedForever) {
          return (lat: null, lng: null);
        }
      }
      if (perm == LocationPermission.deniedForever) {
        return (lat: null, lng: null);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      );
      return (lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      return (lat: null, lng: null);
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_submitting || _done) return;
    final code = capture.barcodes.firstWhere(
      (b) => (b.rawValue ?? '').isNotEmpty,
      orElse: () => const Barcode(),
    );
    final token = code.rawValue;
    if (token == null || token.isEmpty) return;

    setState(() {
      _submitting = true;
      _status = null;
    });
    await _ctrl.stop();

    final loc = await _tryLocation();
    try {
      final lateMinutes = await QrAttendanceService.claimAttendance(
        token: token,
        lat: loc.lat,
        lng: loc.lng,
      );
      if (!mounted) return;
      setState(() {
        _done = true;
        _submitting = false;
        _status = lateMinutes > 0
            ? 'Checked in — $lateMinutes minute(s) late.'
            : 'Checked in. You\'re on time!';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _status = _humanError(e);
      });
      // Let the user re-scan after an error.
      await _ctrl.start();
    }
  }

  String _humanError(Object e) {
    final s = e.toString();
    if (s.contains('expired')) return 'This QR code has expired.';
    if (s.contains('already checked')) return 'You already checked in.';
    if (s.contains('Invalid QR')) return 'Not a valid attendance code.';
    if (s.contains('Member not found')) {
      return 'Your account is not linked to a member profile.';
    }
    return 'Could not check in: $s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan to Check In'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _ctrl.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: () => _ctrl.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!_done)
            MobileScanner(
              controller: _ctrl,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Camera error: $error',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          if (!_done) _scannerOverlay(),
          if (_done) _doneCard(),
          if (_status != null && !_done) _statusBanner(),
          if (_submitting)
            Container(
              color: Colors.black45,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _scannerOverlay() {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.accent, width: 3),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _statusBanner() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 24,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Material(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _status!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _doneCard() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(28),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle,
                size: 64, color: AppColors.secondary),
            const SizedBox(height: 14),
            Text(
              _status ?? 'Checked in',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
