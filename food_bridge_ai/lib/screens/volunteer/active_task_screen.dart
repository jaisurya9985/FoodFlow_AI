import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/donation_model.dart';
import '../../providers/donation_provider.dart';
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
    final deliveryLatLng = LatLng(
      d.pickupLocation.lat + 0.01,
      d.pickupLocation.lng + 0.01,
    );

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
            flex: 3,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: pickupLatLng,
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.food_bridge_ai',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [pickupLatLng, deliveryLatLng],
                      color: AppColors.forestGreen,
                      strokeWidth: 4,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: pickupLatLng,
                      width: 40,
                      height: 40,
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
                    Marker(
                      point: deliveryLatLng,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.forestGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.volunteer_activism_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
