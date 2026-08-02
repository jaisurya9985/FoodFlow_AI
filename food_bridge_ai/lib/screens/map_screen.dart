import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/donation_provider.dart';
import '../models/donation_model.dart';
import '../utils/app_colors.dart';
import '../widgets/risk_badge.dart';
import '../widgets/countdown_timer.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  String _filter = 'All';
  final List<String> _filters = ['All', 'HIGH Risk', 'Near Me', 'Cooked Meals'];
  DonationModel? _selectedDonation;
  final MapController _mapController = MapController();

  LatLng? _userLocation;
  bool _locating = true;
  String? _locationError;

  static const double _nearMeKm = 5.0; // km radius for "Near Me"
  static const _defaultCenter = LatLng(13.05, 80.21); // fallback: Chennai

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    setState(() { _locating = true; _locationError = null; });

    try {
      // Check service
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locating = false;
          _locationError = 'Location services are off';
          _userLocation = _defaultCenter;
        });
        return;
      }

      // Check / request permission
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        setState(() {
          _locating = false;
          _locationError = 'Location permission denied';
          _userLocation = _defaultCenter;
        });
        return;
      }

      // Get actual position with a timeout
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _userLocation = loc;
        _locating = false;
      });

      // Pan map to real location
      _mapController.move(loc, 14);
    } catch (e) {
      if (mounted) {
        setState(() {
          _locating = false;
          _locationError = 'Offline or location disabled';
          _userLocation = _defaultCenter;
        });
      }
    }
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const distCalc = Distance();
    return distCalc.as(
      LengthUnit.Kilometer,
      LatLng(lat1, lon1),
      LatLng(lat2, lon2),
    );
  }

  List<DonationModel> _applyFilter(List<DonationModel> donations) {
    switch (_filter) {
      case 'HIGH Risk':
        return donations.where((d) => d.riskLabel == RiskLabel.high).toList();
      case 'Cooked Meals':
        return donations.where((d) => d.category == FoodCategory.cookedMeal).toList();
      case 'Near Me':
        if (_userLocation == null) return donations;
        return donations.where((d) {
          final dist = _distanceKm(
            _userLocation!.latitude, _userLocation!.longitude,
            d.pickupLocation.lat, d.pickupLocation.lng,
          );
          return dist <= _nearMeKm;
        }).toList();
      default:
        return donations;
    }
  }

  Color _markerColor(RiskLabel risk) {
    switch (risk) {
      case RiskLabel.high: return AppColors.riskHigh;
      case RiskLabel.medium: return AppColors.riskMedium;
      default: return AppColors.riskLow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final donationProv = context.watch<DonationProvider>();

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────────
          StreamBuilder<List<DonationModel>>(
            stream: donationProv.allActiveStream,
            builder: (context, snap) {
              final allDonations = (snap.data ?? []).where((d) => !d.isExpired).toList();
              final donations = _applyFilter(allDonations);
              final center = _userLocation ?? _defaultCenter;

              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 13,
                  onTap: (_, __) => setState(() => _selectedDonation = null),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.food_bridge_ai',
                  ),
                  MarkerLayer(
                    markers: [
                      // Real user location dot
                      if (_userLocation != null)
                        Marker(
                          point: _userLocation!,
                          width: 24,
                          height: 24,
                          child: _PulsingDot(),
                        ),

                      // Donation markers
                      ...donations.map((d) => Marker(
                        point: LatLng(d.pickupLocation.lat, d.pickupLocation.lng),
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedDonation = d);
                            _mapController.move(
                              LatLng(d.pickupLocation.lat, d.pickupLocation.lng),
                              15,
                            );
                          },
                          child: _DonationMarker(
                            color: _markerColor(d.riskLabel),
                            isSelected: _selectedDonation?.id == d.id,
                          ),
                        ),
                      )),
                    ],
                  ),
                ],
              );
            },
          ),

          // ── Top overlay: My Location + Filter chips ───────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 12,
            right: 12,
            child: Column(
              children: [
                // Location status banner
                if (_locating)
                  _glassChip(
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.mossGreen)),
                        SizedBox(width: 8),
                        Text('Getting your location…',
                            style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
                      ],
                    ),
                  )
                else if (_locationError != null)
                  GestureDetector(
                    onTap: _fetchLocation,
                    child: _glassChip(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_off_rounded, size: 14, color: AppColors.riskHigh),
                          const SizedBox(width: 6),
                          Text(_locationError!, style: const TextStyle(fontSize: 12, color: AppColors.riskHigh)),
                          const SizedBox(width: 6),
                          const Text('↺ Retry', style: TextStyle(fontSize: 12, color: AppColors.amber, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  )
                else if (_userLocation != null)
                  _glassChip(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle, color: AppColors.mossGreen,
                            boxShadow: [BoxShadow(color: AppColors.mossGreen.withOpacity(0.8), blurRadius: 6)],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('Live location active',
                            style: TextStyle(fontSize: 12, color: AppColors.mossGreen, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // Filter chips row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((f) {
                      final isSelected = _filter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _filter = f;
                            _selectedDonation = null;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.mossGreen
                                  : AppColors.darkCard.withOpacity(0.92),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.mossGreen
                                    : const Color(0xFF1E3D2E),
                                width: 1,
                              ),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: AppColors.mossGreen.withOpacity(0.4), blurRadius: 10)]
                                  : [const BoxShadow(color: AppColors.shadowDark, blurRadius: 6)],
                            ),
                            child: Text(
                              f,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.black : AppColors.textDark,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ).animate().fadeIn().slideY(begin: -0.1, end: 0),
          ),

          // ── "My Location" FAB ────────────────────────────────────────────────
          Positioned(
            bottom: _selectedDonation != null ? 240 : 90,
            right: 12,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: GestureDetector(
                key: ValueKey(_locating),
                onTap: () {
                  if (_userLocation != null) {
                    _mapController.move(_userLocation!, 15);
                  } else {
                    _fetchLocation();
                  }
                },
                child: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1E3D2E), width: 1),
                    boxShadow: const [BoxShadow(color: AppColors.shadowDark, blurRadius: 14)],
                  ),
                  child: _locating
                      ? const Center(child: SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.mossGreen)))
                      : const Icon(Icons.my_location_rounded, color: AppColors.mossGreen, size: 22),
                ),
              ),
            ),
          ),

          // ── Legend ───────────────────────────────────────────────────────────
          Positioned(
            bottom: _selectedDonation != null ? 240 : 90,
            left: 12,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.darkCard.withOpacity(0.92),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E3D2E), width: 1),
                boxShadow: const [BoxShadow(color: AppColors.shadowDark, blurRadius: 10)],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LegendItem(color: AppColors.riskHigh, label: 'HIGH Risk'),
                  SizedBox(height: 4),
                  _LegendItem(color: AppColors.riskMedium, label: 'MEDIUM'),
                  SizedBox(height: 4),
                  _LegendItem(color: AppColors.riskLow, label: 'FRESH'),
                ],
              ),
            ),
          ),

          // ── Donation bottom sheet ─────────────────────────────────────────────
          if (_selectedDonation != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _DonationSheet(
                donation: _selectedDonation!,
                userLocation: _userLocation,
                onClose: () => setState(() => _selectedDonation = null),
                distanceKmFn: _distanceKm,
              ).animate().slideY(begin: 0.3, end: 0, duration: 300.ms, curve: Curves.easeOutCubic),
            ),
        ],
      ),
    );
  }

  Widget _glassChip(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.darkCard.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E3D2E), width: 1),
        boxShadow: const [BoxShadow(color: AppColors.shadowDark, blurRadius: 8)],
      ),
      child: child,
    );
  }
}

// ── Pulsing blue dot for user location ───────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.8, end: 1.4).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _scale,
          builder: (_, __) => Container(
            width: 24 * _scale.value,
            height: 24 * _scale.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withOpacity(0.2),
            ),
          ),
        ),
        Container(
          width: 14, height: 14,
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.5), blurRadius: 8)],
          ),
        ),
      ],
    );
  }
}

// ── Donation map marker ───────────────────────────────────────────────────────
class _DonationMarker extends StatelessWidget {
  final Color color;
  final bool isSelected;
  const _DonationMarker({required this.color, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isSelected ? 48 : 40,
      height: isSelected ? 48 : 40,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: isSelected ? 16 : 8, spreadRadius: isSelected ? 3 : 1)],
      ),
      child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 20),
    );
  }
}

// ── Selected Donation Bottom Sheet ───────────────────────────────────────────
class _DonationSheet extends StatelessWidget {
  final DonationModel donation;
  final LatLng? userLocation;
  final VoidCallback onClose;
  final double Function(double, double, double, double) distanceKmFn;

  const _DonationSheet({
    required this.donation,
    required this.userLocation,
    required this.onClose,
    required this.distanceKmFn,
  });

  @override
  Widget build(BuildContext context) {
    final d = donation;
    double? dist;
    if (userLocation != null) {
      dist = distanceKmFn(
        userLocation!.latitude, userLocation!.longitude,
        d.pickupLocation.lat, d.pickupLocation.lng,
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: const Border(top: BorderSide(color: Color(0xFF1E3D2E), width: 1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, -6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFF2A4A38), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: AppColors.darkCardAlt, borderRadius: BorderRadius.circular(16)),
                child: Center(child: Text(d.category.icon, style: const TextStyle(fontSize: 26))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${d.quantityKg.toStringAsFixed(0)} kg · by ${d.donorName}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
                  ],
                ),
              ),
              RiskBadge(risk: d.riskLabel),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: AppColors.darkCardAlt, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textLight),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Location + distance
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 14, color: AppColors.textLight),
              const SizedBox(width: 4),
              Expanded(
                child: Text(d.pickupLocation.address,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMedium),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              if (dist != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.teal.withOpacity(0.3)),
                  ),
                  child: Text(
                    dist < 1 ? '${(dist * 1000).toStringAsFixed(0)} m away'
                             : '${dist.toStringAsFixed(1)} km away',
                    style: const TextStyle(fontSize: 11, color: AppColors.teal, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // Footer row: timer + status
          Row(
            children: [
              CountdownTimer(expiryTime: d.expiryTime),
              const Spacer(),
              if (d.matchedNGOName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.mossGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.mossGreen.withOpacity(0.3)),
                  ),
                  child: Text('NGO: ${d.matchedNGOName}',
                      style: const TextStyle(fontSize: 11, color: AppColors.mossGreen, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Legend item ───────────────────────────────────────────────────────────────
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            color: color, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 4)],
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMedium, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
