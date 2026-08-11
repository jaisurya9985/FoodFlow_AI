import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/donation_model.dart';
import '../../models/user_model.dart';
import '../../providers/donation_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/location_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/countdown_timer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ActiveTaskScreen extends StatefulWidget {
  final DonationModel donation;
  const ActiveTaskScreen({super.key, required this.donation});

  @override
  State<ActiveTaskScreen> createState() => _ActiveTaskScreenState();
}

class _ActiveTaskScreenState extends State<ActiveTaskScreen> {
  final DateTime _startTime = DateTime.now();
  bool _dialogShown = false;

  Future<void> _markPickedUp() async {
    final prov = context.read<DonationProvider>();
    final ok = await prov.markPickedUp(widget.donation.id);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Marked as picked up!'),
          backgroundColor: AppColors.mossGreen,
        ),
      );
    }
  }

  Future<void> _confirmDropoff() async {
    final prov = context.read<DonationProvider>();
    final ok = await prov.volunteerConfirmDropoff(widget.donation.id);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📦 Drop-off logged! Waiting for NGO...'),
          backgroundColor: AppColors.mossGreen,
        ),
      );
    }
  }

  void _showCompletionDialog() {
    if (_dialogShown) return;
    _dialogShown = true;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text(
                'Delivery Complete!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You earned 50 points! Thank you for helping your community.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMedium,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.donation;
    final pickupLatLng = LatLng(d.pickupLocation.lat, d.pickupLocation.lng);
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Active Task'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElapsedTimer(startTime: _startTime),
          ),
        ],
      ),
      body: Column(
        children: [
          // Map
          Expanded(
            flex: 4,
            child: StreamBuilder<UserModel?>(
              stream: currentUid.isEmpty ? Stream<UserModel?>.empty() : FirebaseService.userStream(currentUid),
              builder: (context, volunteerSnap) {
                final volunteerLocation = volunteerSnap.data?.location;
                final currentLatLng = volunteerLocation == null
                    ? pickupLatLng
                    : LatLng(volunteerLocation.lat, volunteerLocation.lng);

                return StreamBuilder<UserModel?>(
                  stream: d.matchedNGOId == null
                      ? Stream<UserModel?>.empty()
                      : FirebaseService.userStream(d.matchedNGOId!),
                  builder: (context, ngoSnap) {
                    final ngoLocation = ngoSnap.data?.location;
                    final ngoLatLng = ngoLocation == null
                        ? null
                        : LatLng(ngoLocation.lat, ngoLocation.lng);

                    final routePoints = <LatLng>[
                      currentLatLng,
                      if (d.status == DonationStatus.pickedUp && ngoLatLng != null)
                        ngoLatLng
                      else
                        pickupLatLng,
                    ];

                    return Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCenter: currentLatLng,
                            initialZoom: 13.5,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.food_bridge_ai',
                            ),
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: routePoints,
                                  color: AppColors.forestGreen,
                                  strokeWidth: 4,
                                ),
                              ],
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: pickupLatLng,
                                  width: 44,
                                  height: 44,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: AppColors.amber,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.restaurant_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                if (ngoLatLng != null)
                                  Marker(
                                    point: ngoLatLng,
                                    width: 44,
                                    height: 44,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: AppColors.mossGreen,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.volunteer_activism_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                Marker(
                                  point: currentLatLng,
                                  width: 44,
                                  height: 44,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: AppColors.forestGreen,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.delivery_dining_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Positioned(
                          top: 16,
                          left: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.92),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [
                                BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 4)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.status == DonationStatus.pickedUp
                                      ? 'Head to NGO drop-off'
                                      : 'Navigate to donor pickup',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  d.status == DonationStatus.pickedUp
                                      ? 'Pickup done. Take the shortest path to the NGO now.'
                                      : 'Follow the route to collect the food from the donor.',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMedium),
                                ),
                                if (volunteerLocation != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Distance to pickup: ${LocationService.formatDistance(LocationService.calculateDistance(currentLatLng.latitude, currentLatLng.longitude, pickupLatLng.latitude, pickupLatLng.longitude))}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.mossGreen),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Bottom panel
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Donation info
                Row(children: [
                  Text(d.category.icon, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.title,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        Text(
                          '${d.quantityKg.toStringAsFixed(0)} kg · from ${d.donorName}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMedium),
                        ),
                      ],
                    ),
                  ),
                  CountdownTimer(
                    expiryTime: d.expiryTime,
                    compact: false,
                  ),
                ]),

                const SizedBox(height: 16),

                // Location row
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGrey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(children: [
                    _LocationRow(
                      icon: Icons.restaurant_rounded,
                      color: AppColors.amber,
                      label: 'Pickup',
                      address: d.pickupLocation.address,
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 24),
                      child: Divider(),
                    ),
                    _LocationRow(
                      icon: Icons.volunteer_activism_rounded,
                      color: AppColors.mossGreen,
                      label: 'Dropoff',
                      address: d.matchedNGOName ?? 'NGO Location',
                    ),
                  ]),
                ),

                const SizedBox(height: 16),

                StreamBuilder<UserModel?>(
                  stream: d.matchedNGOId == null ? Stream<UserModel?>.empty() : FirebaseService.userStream(d.matchedNGOId!),
                  builder: (context, ngoSnap) {
                    final ngoLoc = ngoSnap.data?.location;
                    if (ngoLoc == null) {
                      return const SizedBox.shrink();
                    }
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGrey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'NGO route ready. The drop-off map will follow ${d.matchedNGOName ?? "the NGO"} as soon as pickup is marked complete.',
                        style: const TextStyle(fontSize: 12, color: AppColors.textDark, height: 1.4),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Action button wrapper
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('donations').doc(d.id).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final liveModel = DonationModel.fromFirestore(snapshot.data!);

                    // If both confirmed, pop the dialog
                    if (liveModel.volunteerDroppedOff && liveModel.ngoReceived) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _showCompletionDialog();
                      });
                    }

                    return SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: (liveModel.status == DonationStatus.delivered)
                          ? Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.riskLow.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Text('✅ Handshake Complete!',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.riskLow,
                                  )),
                            )
                          : liveModel.volunteerDroppedOff
                              ? Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
                                  ),
                                  child: const Text('Waiting for NGO confirmation...',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.amber,
                                      )),
                                )
                              : liveModel.status == DonationStatus.pickedUp
                                  ? ElevatedButton.icon(
                                      onPressed: _confirmDropoff,
                                      icon: const Icon(Icons.handshake_rounded, color: Colors.white),
                                      label: const Text('Confirm Drop-off',
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.mossGreen,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                    )
                                  : ElevatedButton.icon(
                                      onPressed: _markPickedUp,
                                      icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                                      label: const Text('Mark as Picked Up',
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.amber,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                    ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String address;

  const _LocationRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textLight)),
            Text(address,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    ]);
  }
}
