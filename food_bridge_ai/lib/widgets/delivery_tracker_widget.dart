import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/donation_model.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../utils/app_colors.dart';

/// Swiggy/Zomato-style Delivery Tracker Component (Full-Width, Non-Collapsing)
class DeliveryTrackerWidget extends StatelessWidget {
  final DonationModel donation;

  const DeliveryTrackerWidget({
    super.key,
    required this.donation,
  });

  int _getStepIndex() {
    switch (donation.status) {
      case DonationStatus.matched:
      case DonationStatus.searching:
        return 1;
      case DonationStatus.accepted:
        return 2;
      case DonationStatus.pickedUp:
        return 3;
      case DonationStatus.delivered:
        return 4;
      default:
        return 0;
    }
  }

  int _calculateEtaMinutes(double distKm) {
    if (distKm <= 0) return 3;
    final mins = (distKm / 20.0 * 60).round();
    return mins < 2 ? 2 : mins;
  }

  void _openLiveTrackingSheet(BuildContext context, UserModel? volunteer) {
    final fallbackVol = volunteer ??
        UserModel(
          uid: donation.assignedVolunteerId ?? 'vol',
          name: donation.assignedVolunteerName ?? 'Volunteer Rider',
          email: '',
          phone: '9876543230',
          role: UserRole.volunteer,
          rating: 4.8,
          createdAt: DateTime.now(),
        );

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LiveTrackingMapSheet(
        donation: donation,
        volunteer: fallbackVol,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stepIndex = _getStepIndex();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.amber.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row: Rider Status Title + LIVE Radar Pill Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.amber.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delivery_dining_rounded,
                  color: AppColors.amber,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  donation.status == DonationStatus.pickedUp
                      ? 'On the way to NGO 🚴'
                      : donation.status == DonationStatus.accepted
                          ? 'Rider assigned & heading to donor 📍'
                          : 'Order Processing',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 1.0, end: 0.2),
                    const SizedBox(width: 4),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: Colors.redAccent,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Horizontal Progress Stepper Bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF141420),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCompactStep(1, 'Matched', stepIndex >= 1),
                _buildStepDivider(stepIndex >= 2),
                _buildCompactStep(2, 'Assigned', stepIndex >= 2),
                _buildStepDivider(stepIndex >= 3),
                _buildCompactStep(3, 'Picked Up', stepIndex >= 3),
                _buildStepDivider(stepIndex >= 4),
                _buildCompactStep(4, 'Delivered', stepIndex >= 4),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Volunteer Live Distance & Track on Map Button Block
          if (donation.assignedVolunteerId != null && donation.assignedVolunteerId!.isNotEmpty)
            StreamBuilder<UserModel?>(
              stream: FirebaseService.userStream(donation.assignedVolunteerId!),
              builder: (context, snap) {
                final vol = snap.data;
                final loc = vol?.location;

                final distKm = loc != null
                    ? LocationService.calculateDistance(
                        donation.pickupLocation.lat,
                        donation.pickupLocation.lng,
                        loc.lat,
                        loc.lng,
                      )
                    : 2.0;

                final etaMins = _calculateEtaMinutes(distKm);
                final volName = vol?.name ?? donation.assignedVolunteerName ?? 'Volunteer Rider';
                final volRating = vol?.rating ?? 4.8;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF272738),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      // ETA Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.mossGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.mossGreen.withOpacity(0.4)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '~$etaMins MINS',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AppColors.mossGreen,
                              ),
                            ),
                            const Text(
                              'ESTIMATED',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Rider Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              volName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              loc != null
                                  ? '${LocationService.formatDistance(distKm)} away · ⭐ ${volRating.toStringAsFixed(1)}'
                                  : 'En route · ⭐ ${volRating.toStringAsFixed(1)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Track on Live Map Button
                      ElevatedButton.icon(
                        onPressed: () => _openLiveTrackingSheet(context, vol),
                        icon: const Icon(Icons.map_rounded, size: 13),
                        label: const Text('Live Map', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.amber,
                          foregroundColor: Colors.black,
                          elevation: 2,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCompactStep(int stepNumber, String label, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: isActive ? AppColors.amber : const Color(0xFF2C2C3D),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isActive ? Icons.check : Icons.circle,
            size: 10,
            color: isActive ? Colors.black : Colors.white24,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            color: isActive ? Colors.white : Colors.white38,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 12, left: 2, right: 2),
        color: isActive ? AppColors.amber : const Color(0xFF2C2C3D),
      ),
    );
  }
}

/// Swiggy/Zomato-style Full Interactive Live Map Tracking Sheet
class _LiveTrackingMapSheet extends StatelessWidget {
  final DonationModel donation;
  final UserModel volunteer;

  const _LiveTrackingMapSheet({
    required this.donation,
    required this.volunteer,
  });

  void _showCallDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Call ${volunteer.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_in_talk_rounded, color: AppColors.mossGreen, size: 48),
            const SizedBox(height: 12),
            Text(
              volunteer.phone.isNotEmpty ? volunteer.phone : '9876543230',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Direct line to your assigned volunteer rider.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMedium),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pickupLatLng = LatLng(donation.pickupLocation.lat, donation.pickupLocation.lng);

    return StreamBuilder<UserModel?>(
      stream: FirebaseService.userStream(volunteer.uid),
      builder: (context, snap) {
        final liveVol = snap.data ?? volunteer;
        final volLoc = liveVol.location;
        final riderLatLng = volLoc != null
            ? LatLng(volLoc.lat, volLoc.lng)
            : pickupLatLng;

        final distKm = LocationService.calculateDistance(
          donation.pickupLocation.lat,
          donation.pickupLocation.lng,
          riderLatLng.latitude,
          riderLatLng.longitude,
        );

        final routePoints = [riderLatLng, pickupLatLng];

        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF161622),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Sheet handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Top Header Card: Order Title & ETA
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              donation.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Live tracking · ${LocationService.formatDistance(distKm)} away',
                              style: const TextStyle(fontSize: 11, color: AppColors.textMedium),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Map View
                Expanded(
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: riderLatLng,
                          initialZoom: 14.0,
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
                                color: AppColors.amber,
                                strokeWidth: 4,
                              ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              // Pickup Marker
                              Marker(
                                point: pickupLatLng,
                                width: 40,
                                height: 40,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: AppColors.amber,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.restaurant, color: Colors.black, size: 20),
                                ),
                              ),
                              // Rider Live Marker
                              Marker(
                                point: riderLatLng,
                                width: 44,
                                height: 44,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.mossGreen,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.mossGreen.withOpacity(0.5),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 24),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Swiggy-style Live Status Floating Overlay
                      Positioned(
                        top: 12,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.amber.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.directions_bike_rounded, color: AppColors.amber, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  donation.status == DonationStatus.pickedUp
                                      ? 'Food collected! On the way to NGO'
                                      : 'Volunteer is heading to pickup address',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Swiggy-style Volunteer Profile & Call Action
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E1E2C),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.amber.withOpacity(0.2),
                        child: const Icon(Icons.person, color: AppColors.amber, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              liveVol.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 13),
                                const SizedBox(width: 3),
                                Text(
                                  '${liveVol.rating.toStringAsFixed(1)} rating · Verified Helper 🛵',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMedium),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showCallDialog(context),
                        icon: const Icon(Icons.phone_rounded, size: 16),
                        label: const Text('Call', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mossGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
