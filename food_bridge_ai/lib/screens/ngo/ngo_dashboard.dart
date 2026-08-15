import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/donation_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/donation_provider.dart';
import '../../services/firebase_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/shimmer_list.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/countdown_timer.dart';
import '../../services/notification_service.dart';
import '../../widgets/rate_volunteer_button.dart';
import '../../widgets/delivery_tracker_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class NGODashboard extends StatefulWidget {
  const NGODashboard({super.key});

  @override
  State<NGODashboard> createState() => _NGODashboardState();
}

class _NGODashboardState extends State<NGODashboard> {
  List<UserModel> _volunteers = [];
  StreamSubscription<List<UserModel>>? _volunteersSub;
  StreamSubscription<List<DonationModel>>? _donationSub;
  StreamSubscription<List<DonationModel>>? _statusSub;
  Set<String> _seenDonationIds = {};
  final Map<String, String> _seenStatuses = {};

  @override
  void initState() {
    super.initState();
    _loadVolunteers();
    _setupNotificationListener();
    _setupStatusListener();
    
    // Delay permissions for 3s to prevent ANR during initial render
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        NotificationService.requestPermissions().catchError((_) => null);
      }
    });
  }

  void _setupNotificationListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<DonationProvider>();

      _donationSub = prov.availableStream.listen((donations) {
        if (_seenDonationIds.isEmpty) {
          _seenDonationIds = donations.map((d) => d.id).toSet();
          return;
        }

        for (var d in donations) {
          if (!_seenDonationIds.contains(d.id) && !d.isExpired) {
            NotificationService.showLocalNotification(
              title: 'New Surplus Food Available!',
              body: '${d.quantityKg}kg of ${d.category.displayName} near you.',
            );
            _seenDonationIds.add(d.id);
          }
        }
      });
    });
  }

  void _setupStatusListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<DonationProvider>();
      _statusSub = prov.allActiveStream.listen((donations) async {
        for (final d in donations) {
          final prev = _seenStatuses[d.id];
          final current = d.status.name;
          if (prev == null) {
            _seenStatuses[d.id] = current;
            continue;
          }
          if (prev == current) continue;
          _seenStatuses[d.id] = current;

          String title;
          String body;
          switch (d.status) {
            case DonationStatus.accepted:
              title = 'Volunteer accepted task';
              body = '${d.assignedVolunteerName ?? "Volunteer"} is heading to pickup.';
              break;
            case DonationStatus.pickedUp:
              title = 'Food picked up';
              body = 'The volunteer has started delivery to the NGO.';
              break;
            case DonationStatus.delivered:
              title = 'Delivery completed';
              body = 'The donation reached the NGO.';
              break;
            default:
              continue;
          }
          await NotificationService.showLocalNotification(title: title, body: body);
        }
      });
    });
  }

  Future<void> _loadVolunteers() async {
    _volunteersSub = FirebaseService.volunteersStream().listen((vols) {
      if (mounted) setState(() => _volunteers = vols);
    });
  }

  @override
  void dispose() {
    _volunteersSub?.cancel();
    _donationSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    final user = auth.userModel;
    final uid = auth.firebaseUser?.uid ?? '';
    final donationProv = context.watch<DonationProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF060C12),
      body: Stack(
        children: [
          Positioned(
            top: -60, right: -60,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [const Color(0xFF0097A7).withOpacity(0.2), Colors.transparent]),
              ),
            ),
          ),
          Positioned(
            bottom: 150, left: -80,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [const Color(0xFF1565C0).withOpacity(0.15), Colors.transparent]),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _NGOGridPainter()),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF006064), Color(0xFF00ACC1)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [BoxShadow(color: const Color(0xFF00BCD4).withOpacity(0.4), blurRadius: 16)],
                          ),
                          child: Center(
                            child: Text(
                              user?.initials ?? 'N',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
                            ),
                          ),
                        ).animate().fadeIn().scale(begin: const Offset(0.85, 0.85), end: const Offset(1.0, 1.0), curve: Curves.elasticOut, duration: 600.ms),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                ShaderMask(
                                  shaderCallback: (b) => const LinearGradient(
                                    colors: [Color(0xFF00E5FF), Color(0xFF00BCD4)],
                                  ).createShader(b),
                                  child: const Text(
                                    'Operations Center',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0097A7).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.4)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified_rounded,
                                          size: 10, color: Color(0xFF00E5FF)),
                                      SizedBox(width: 3),
                                      Text('NGO',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.mossGreen,
                                           )),
                                    ],
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 2),
                              Text(
                                user?.orgName ?? user?.name ?? 'Organisation',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF607D8B)),
                              ),
                              const SizedBox(height: 4),
                              const Row(children: [
                                Icon(Icons.people_rounded, size: 12, color: Color(0xFF00BCD4)),
                                SizedBox(width: 4),
                                Text('Coordinating community food rescue',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF455A64))),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ).animate().fadeIn().slideY(begin: -0.1, end: 0),

                    const SizedBox(height: 20),

                    // Stats bar
                    StreamBuilder<List<DonationModel>>(
                      stream: donationProv.ngoClaimedStream(uid),
                      builder: (context, snap) {
                        return Row(children: [
                          _NGOStatPill(icon: Icons.inventory_2_rounded, label: 'Active', value: '${(snap.data ?? []).where((d) => !d.isExpired).length}', color: const Color(0xFF00BCD4)),
                          const SizedBox(width: 10),
                          _NGOStatPill(icon: Icons.local_shipping_rounded, label: 'In Transit', value: '${(snap.data ?? []).where((d) => d.status == DonationStatus.pickedUp).length}', color: const Color(0xFF9C6FFF)),
                          const SizedBox(width: 10),
                          _NGOStatPill(icon: Icons.check_circle_rounded, label: 'Delivered', value: '${(snap.data ?? []).where((d) => d.status == DonationStatus.delivered).length}', color: const Color(0xFF00E5A0)),
                        ]);
                      },
                    ).animate(delay: 100.ms).fadeIn().slideX(begin: -0.06, end: 0),

                    const SizedBox(height: 20),

                    // Available food section label
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00BCD4).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.radar_rounded, color: Color(0xFF00BCD4), size: 16),
                      ),
                      const SizedBox(width: 10),
                      const Text('Available Food to Rescue',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                              color: Color(0xFFCFD8DC), letterSpacing: -0.2)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00BCD4).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
                        ),
                        child: const Text('Live', style: TextStyle(fontSize: 11, color: Color(0xFF00E5FF), fontWeight: FontWeight.w700)),
                      ),
                    ]).animate(delay: 150.ms).fadeIn(),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // Available donations stream
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: StreamBuilder<List<DonationModel>>(
                stream: donationProv.availableStream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(
                        child: ShimmerLoadingList());
                  }
                  if (snap.hasError) {
                    return const SliverToBoxAdapter(
                      child: EmptyStateWidget(
                        icon: Icons.cloud_off_rounded,
                        message: 'Offline Mode',
                        subMessage: 'Check your connection to see available donations',
                      ),
                    );
                  }
                  if (!snap.hasData || snap.data!.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: EmptyStateWidget(
                        icon: Icons.check_circle_outline,
                        message: 'No donations available right now',
                        subMessage: 'Check back soon — donors post frequently!',
                      ),
                    );
                  }

                  final donations = snap.data!.where((d) => !d.isExpired).toList();
                  final urgent = donations
                      .where((d) => d.riskLabel == RiskLabel.high)
                      .toList();
                  final others = donations
                      .where((d) => d.riskLabel != RiskLabel.high)
                      .toList();

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final totalList = [...urgent, ...others];
                        final d = totalList[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _NGODonationCard(
                            donation: d,
                            volunteers: _volunteers,
                            uid: uid,
                            ngoName: user?.orgName ?? user?.name ?? 'NGO',
                          ),
                        );
                      },
                      childCount: [...urgent, ...others].length,
                    ),
                  );
                },
              ),
            ),

            // Active pickups
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9C6FFF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF9C6FFF), size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Text('Your Active Pickups',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFCFD8DC))),
                ]),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: StreamBuilder<List<DonationModel>>(
                stream: donationProv.ngoClaimedStream(uid),
                builder: (ctx, snap) {
                  final activePickups = (snap.data ?? []).where((d) => !d.isExpired).toList();
                  if (activePickups.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: EmptyStateWidget(
                        icon: Icons.local_shipping_outlined,
                        message: 'No active pickups',
                        subMessage: 'Claim a donation above to get started.',
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final d = activePickups[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ActivePickupCard(donation: d),
                        );
                      },
                      childCount: activePickups.length,
                    ),
                  );
                },
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
          ],
        ),
      ),
        ],
      ),
    );
  }
}

class _NGODonationCard extends StatefulWidget {
  final DonationModel donation;
  final List<UserModel> volunteers;
  final String uid;
  final String ngoName;

  const _NGODonationCard({
    required this.donation,
    required this.volunteers,
    required this.uid,
    required this.ngoName,
  });

  @override
  State<_NGODonationCard> createState() => _NGODonationCardState();
}

class _NGODonationCardState extends State<_NGODonationCard> {
  bool _claiming = false;

  Color get _borderColor {
    switch (widget.donation.riskLabel) {
      case RiskLabel.high:
        return AppColors.riskHigh;
      case RiskLabel.medium:
        return AppColors.riskMedium;
      default:
        return AppColors.riskLow;
    }
  }

  Future<void> _claim() async {
    setState(() => _claiming = true);
    final prov = context.read<DonationProvider>();

    final queued = await prov.requestVolunteerSearch(
      donationId: widget.donation.id,
      ngoId: widget.uid,
      ngoName: widget.ngoName,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(queued
            ? 'Searching for an online volunteer. We will notify you when one accepts.'
            : 'Unable to start volunteer search. Please try again.'),
        backgroundColor: queued ? AppColors.mossGreen : AppColors.riskHigh,
      ),
    );
    setState(() => _claiming = false);
    return;

    /* Legacy foreground matcher retained temporarily for reference.
    bool aborted = false;
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: _FindingVolunteerDialog(
          donationId: widget.donation.id,
          onCancel: () {
            aborted = true;
            Navigator.pop(ctx, false);
          },
          onMatched: (vol) {
            // This is called when status becomes 'accepted'
            Navigator.pop(ctx, true);
          },
          // Trigger the search process
          searchFuture: prov.claimDonation(
            donationId: widget.donation.id,
            ngoId: widget.uid,
            ngoName: widget.ngoName,
            donation: widget.donation,
            availableVolunteers: widget.volunteers,
            isCancelled: () => aborted,
          ),
        ),
      ),
    );

    if (aborted || result != true) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Volunteer accepted your task — They are on the way!'),
          backgroundColor: AppColors.mossGreen,
        ),
      );
    }

    if (mounted) setState(() => _claiming = false);
    */
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.donation;
    final matchScore = 85 + (d.riskScore * 3);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(color: _borderColor.withOpacity(0.12), blurRadius: 16),
          const BoxShadow(color: AppColors.shadowDark, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                d.category.icon,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${d.quantityKg.toStringAsFixed(0)} kg · by ${d.donorName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              RiskBadge(risk: d.riskLabel),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 12, color: AppColors.textLight),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  d.pickupLocation.address,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMedium,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: AppColors.purpleGradient),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$matchScore% match',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(children: [
            CountdownTimer(expiryTime: d.expiryTime, compact: true),
            const Spacer(),
            // Claim button
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.mintGradient),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: AppColors.mossGreen.withOpacity(0.3), blurRadius: 12)],
              ),
              child: ElevatedButton(
                onPressed: _claiming ? null : _claim,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _claiming
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text(
                        'Claim Pickup',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black),
                      ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _FindingVolunteerDialog extends StatefulWidget {
  final String donationId;
  final VoidCallback onCancel;
  final Function(UserModel?) onMatched;
  final Future<UserModel?> searchFuture;

  const _FindingVolunteerDialog({
    required this.donationId,
    required this.onCancel,
    required this.onMatched,
    required this.searchFuture,
  });

  @override
  State<_FindingVolunteerDialog> createState() => _FindingVolunteerDialogState();
}

class _FindingVolunteerDialogState extends State<_FindingVolunteerDialog> {
  UserModel? _assignedVolunteer;
  bool _searchFailed = false;

  @override
  void initState() {
    super.initState();
    widget.searchFuture.then((vol) {
      if (vol == null && mounted) {
        setState(() => _searchFailed = true);
      } else if (mounted) {
        setState(() => _assignedVolunteer = vol);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF1E3D2E), width: 1),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          style: TextButton.styleFrom(foregroundColor: AppColors.riskHigh),
          child: const Text('Cancel'),
        ),
      ],
      content: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('donations')
            .doc(widget.donationId)
            .snapshots(),
        builder: (context, snapshot) {
          String title = 'Finding best volunteer...';
          String subTitle = 'Our AI is matching based on proximity, rating, and capacity';
          bool showLoading = true;

          if (_searchFailed) {
            title = 'No volunteers found';
            subTitle = 'Try again in a few minutes or broaded your area.';
            showLoading = false;
          } else if (snapshot.hasData) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            final status = data?['status'] ?? 'available';
            final volName = data?['assignedVolunteerName'] ?? 'a volunteer';

            if (status == 'matched' || status == 'searching') {
              title = 'Searching for volunteer...';
              subTitle = 'AI is finding nearby volunteers...';
            } else if (status == 'accepted' || status == 'picked_up') {
              title = 'Volunteer Assigned!';
              subTitle = '$volName accepted and is on the way to pick up!';
              showLoading = false;
              // Auto-close after a delay
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) widget.onMatched(_assignedVolunteer);
              });
            }
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              if (showLoading)
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.mossGreen),
                  backgroundColor: AppColors.darkCardAlt,
                )
              else
                const Icon(Icons.check_circle_outline, color: AppColors.mossGreen, size: 52).animate().scale(curve: Curves.elasticOut, duration: 500.ms),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMedium,
                ),
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }
}

class _ActivePickupCard extends StatefulWidget {
  final DonationModel donation;
  const _ActivePickupCard({required this.donation});

  @override
  State<_ActivePickupCard> createState() => _ActivePickupCardState();
}

class _ActivePickupCardState extends State<_ActivePickupCard> {
  bool _confirming = false;

  Future<void> _confirmReceipt() async {
    setState(() => _confirming = true);
    final prov = context.read<DonationProvider>();
    final ok = await prov.ngoConfirmReceipt(widget.donation.id);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to confirm receipt')),
      );
    }
    if (mounted) setState(() => _confirming = false);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.donation;
    String statusLabel;
    Color statusColor;

    switch (d.status) {
      case DonationStatus.searching:
      case DonationStatus.matched:
        statusLabel = 'Searching for Vol.';
        statusColor = AppColors.amber;
        break;
      case DonationStatus.accepted:
        statusLabel = 'Volunteer Assigned';
        statusColor = AppColors.teal;
        break;
      case DonationStatus.pickedUp:
        statusLabel = d.ngoReceived ? 'Waiting for Vol.' : 'En Route';
        statusColor = AppColors.purple;
        break;
      case DonationStatus.delivered:
        statusLabel = 'Delivered ✓';
        statusColor = AppColors.riskLow;
        break;
      default:
        statusLabel = 'Available';
        statusColor = AppColors.amber;
    }

    final isVolunteerAccepted = d.status == DonationStatus.accepted ||
        d.status == DonationStatus.pickedUp ||
        d.status == DonationStatus.delivered;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(color: statusColor.withOpacity(0.08), blurRadius: 14),
          const BoxShadow(color: AppColors.shadowDark, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Row
          Row(
            children: [
              Text(d.category.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${d.quantityKg.toStringAsFixed(0)} kg · ${d.category.displayName}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMedium),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.35), width: 1),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          // Live Tracker Widget (Full Width)
          if (isVolunteerAccepted && d.status != DonationStatus.delivered) ...[
            DeliveryTrackerWidget(donation: d),
          ] else if (!isVolunteerAccepted && (d.status == DonationStatus.searching || d.status == DonationStatus.matched)) ...[
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '🔍 Finding volunteer...',
                style: TextStyle(fontSize: 11, color: AppColors.amber),
              ),
            ),
          ],

          // Bottom Action Row
          if (d.status == DonationStatus.pickedUp && !d.ngoReceived) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirming ? null : _confirmReceipt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mossGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _confirming
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Confirm Receipt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ),
          ] else if (d.status == DonationStatus.delivered) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Rate Volunteer:', style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
                const SizedBox(width: 8),
                RateVolunteerButton(
                  volunteerId: d.assignedVolunteerId ?? '',
                  volunteerName: d.assignedVolunteerName ?? 'Volunteer',
                  donationId: d.id,
                  isAlreadyRated: d.isRated,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── NGO Grid Background Painter ───────────────────────────────────────────────
class _NGOGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00BCD4).withOpacity(0.025)
      ..strokeWidth = 0.5;
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(_NGOGridPainter oldDelegate) => false;
}

// ── NGO Stat Pill ────────────────────────────────────────────────────────────
class _NGOStatPill extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _NGOStatPill({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1520),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 12)],
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF455A64))),
      ]),
    ),
  );
}
