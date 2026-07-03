import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../services/auth_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';

/// Lets the member drop a pin on their house. Tap anywhere on the
/// map to set the pin; tap Save to persist to Supabase.
class HouseLocationPickerScreen extends StatefulWidget {
  const HouseLocationPickerScreen({super.key});

  @override
  State<HouseLocationPickerScreen> createState() =>
      _HouseLocationPickerScreenState();
}

class _HouseLocationPickerScreenState extends State<HouseLocationPickerScreen> {
  final MapController _ctrl = MapController();
  final TextEditingController _address = TextEditingController();
  LatLng? _picked;
  LatLng? _myLocation;
  bool _locating = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = AppState.instance.currentMember!;
    if (m.houseLat != null && m.houseLng != null) {
      _picked = LatLng(m.houseLat!, m.houseLng!);
    }
    _address.text = m.houseAddress ?? '';
    // Try to grab the current location in the background so we can
    // show a blue dot. If the member hasn't set a house yet, also
    // recenter the map there.
    _fetchCurrentLocation(centerOnIt: _picked == null);
  }

  Future<void> _fetchCurrentLocation({bool centerOnIt = true}) async {
    setState(() => _locating = true);
    try {
      // Make sure location services are on.
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        throw 'Location services are off on this device';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw 'Location permission denied';
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final here = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() => _myLocation = here);
      if (centerOnIt) {
        _ctrl.move(here, 17.0);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get your location: $e')),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _useMyLocationAsHouse() async {
    if (_myLocation == null) {
      await _fetchCurrentLocation();
    }
    if (_myLocation == null) return;
    setState(() => _picked = _myLocation);
    _ctrl.move(_myLocation!, 17.0);
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  LatLng get _initialCenter {
    if (_picked != null) return _picked!;
    return const LatLng(34.05, 35.85); // North Lebanon-ish default
  }

  double get _initialZoom => _picked != null ? 16.0 : 9.5;

  Future<void> _save() async {
    if (_picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tap the map to place your house pin')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final m = AppState.instance.currentMember!;
      await AuthService.updateProfile(
        id: m.id,
        houseLat: _picked!.latitude,
        houseLng: _picked!.longitude,
        houseAddress: _address.text.trim().isEmpty
            ? null
            : _address.text.trim(),
      );
      AppState.instance.updateProfile(
        houseLat: _picked!.latitude,
        houseLng: _picked!.longitude,
        houseAddress: _address.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My House Location')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            color: AppColors.cream,
            child: Row(
              children: [
                const Icon(Icons.touch_app, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _picked == null
                        ? 'Tap anywhere on the map to place your house.'
                        : 'Pin set. Tap again to adjust.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _ctrl,
                  options: MapOptions(
                    initialCenter: _initialCenter,
                    initialZoom: _initialZoom,
                    minZoom: 2,
                    maxZoom: 19,
                    onTap: (_, point) => setState(() => _picked = point),
                    interactionOptions: const InteractionOptions(
                      flags:
                          InteractiveFlag.pinchZoom |
                          InteractiveFlag.doubleTapZoom |
                          InteractiveFlag.drag |
                          InteractiveFlag.flingAnimation |
                          InteractiveFlag.scrollWheelZoom,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.fayhanationalchoir.app',
                      maxZoom: 19,
                    ),
                    MarkerLayer(
                      markers: [
                        if (_myLocation != null)
                          Marker(
                            point: _myLocation!,
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blueAccent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black38,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_picked != null)
                          Marker(
                            point: _picked!,
                            width: 60,
                            height: 60,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.home,
                              size: 40,
                              color: AppColors.primary,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 4),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('© OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _locating ? null : _useMyLocationAsHouse,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _locating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.my_location,
                                color: AppColors.primary,
                                size: 22,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _address,
                    decoration: const InputDecoration(
                      labelText: 'Address (optional)',
                      hintText: 'Street, neighborhood, city…',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.cream,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Save Location'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
