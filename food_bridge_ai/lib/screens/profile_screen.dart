import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../providers/user_provider.dart';
import '../models/donation_model.dart';
import '../models/user_model.dart';
import '../services/ml_service.dart';
import '../utils/app_colors.dart';
import 'splash_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _showIPDialog(BuildContext context) {
    final controller = TextEditingController(text: MLService.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ML Server IP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter a local server address or your deployed Render URL.',
              style: TextStyle(fontSize: 13, color: AppColors.textMedium),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'ML server URL',
                hintText: 'https://foodflow-ai-mlaa.onrender.com',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                MLService.setBaseUrl(controller.text.trim());
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Server IP updated to ${MLService.baseUrl}')),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    final userProv = context.watch<UserProvider>();
    final user = auth.userModel;

    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.darkBg,
        body: Center(child: CircularProgressIndicator(color: AppColors.mossGreen)),
      );
    }

    final badges = userProv.earnedBadges;
    final allBadges = [
      {'name': 'Food Hero', 'icon': '🌟', 'req': 10, 'color': AppColors.amber},
      {'name': 'Community Champion', 'icon': '🏆', 'req': 50, 'color': AppColors.teal},
      {'name': 'Zero Waste Warrior', 'icon': '⚔️', 'req': 100, 'color': AppColors.mossGreen},
      {'name': 'Legend', 'icon': '👑', 'req': 500, 'color': AppColors.gold},
    ];

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.darkSurface,
            expandedHeight: 200,
            pinned: true,
            leading: const SizedBox.shrink(),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0A2218), AppColors.darkSurface],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -40, right: -40,
                    child: Container(
                      width: 180, height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [AppColors.forestGreen.withOpacity(0.2), Colors.transparent]),
                      ),
                    ),
                  ),
                  Padding(
                  padding: const EdgeInsets.fromLTRB(24, 70, 24, 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: AppColors.mintGradient),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [BoxShadow(color: AppColors.mossGreen.withOpacity(0.4), blurRadius: 20)],
                            ),
                            child: Center(
                              child: Text(
                                user.initials,
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ShaderMask(
                                  shaderCallback: (b) => const LinearGradient(
                                    colors: [AppColors.textDark, AppColors.mossGreen],
                                  ).createShader(b),
                                  child: Text(
                                    user.name,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                Row(children: [_RoleBadge(role: user.role)]),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats grid
                  StreamBuilder<List<DonationModel>>(
                    stream: FirebaseService.completedDonationsStream(user.uid, user.role),
                    builder: (context, snapshot) {
                      // Silently handle errors by showing default/empty state
                      final donations = snapshot.data ?? [];
                      final count = donations.length;
                      final totalKg = donations.fold<double>(0, (sum, d) => sum + d.quantityKg);
                      final co2 = totalKg * 2.5;

                      return GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.8,
                        children: [
                          _StatGridCard(
                            label: user.role == UserRole.donor
                                ? 'Donations' : 'Deliveries',
                            value: '$count',
                            icon: user.role == UserRole.donor
                                ? Icons.eco_rounded
                                : Icons.delivery_dining_rounded,
                            color: AppColors.mossGreen,
                          ),
                          _StatGridCard(
                            label: 'Points',
                            value: '${user.points}',
                            icon: Icons.stars_rounded,
                            color: AppColors.amber,
                          ),
                          _StatGridCard(
                            label: 'CO₂ Saved',
                            value: '${co2.toStringAsFixed(1)} kg',
                            icon: Icons.air_rounded,
                            color: AppColors.forestGreen,
                          ),
                          _StatGridCard(
                            label: 'Rating',
                            value: user.rating.toStringAsFixed(1),
                            icon: Icons.star_rounded,
                            color: Colors.amber,
                          ),
                        ],
                      );
                    },
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 24),

                  // Achievement badges
                  const Text(
                    '🏅 Achievements',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: allBadges.length,
                    itemBuilder: (ctx, i) {
                      final badge = allBadges[i];
                      final earned = badges.contains(badge['name']);
                      final color = badge['color'] as Color;
                      final req = badge['req'] as int;
                      return _BadgeTile(
                        icon: badge['icon'] as String,
                        name: badge['name'] as String,
                        req: req,
                        current: user.deliveriesDone,
                        earned: earned,
                        color: color,
                      ).animate(delay: (i * 100).ms).fadeIn().slideY(
                            begin: 0.2,
                            end: 0,
                          );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Settings
                  const Text(
                    '⚙️ Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.darkCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF1E3D2E), width: 1),
                      boxShadow: const [BoxShadow(color: AppColors.shadowDark, blurRadius: 16, offset: Offset(0, 6))],
                    ),
                    child: Column(
                      children: [
                        _SettingsRow(
                          icon: Icons.notifications_rounded,
                          label: 'Notifications',
                          trailing: Switch(
                            value: true,
                            onChanged: (_) {},
                            activeColor: AppColors.forestGreen,
                          ),
                        ),
                        const Divider(height: 0),
                        _SettingsRow(
                          icon: Icons.location_on_rounded,
                          label: 'Location Access',
                          trailing: Switch(
                            value: true,
                            onChanged: (_) {},
                            activeColor: AppColors.forestGreen,
                          ),
                        ),
                        const Divider(height: 0),
                        _SettingsRow(
                          icon: Icons.lan_rounded,
                          label: 'ML Server IP',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.forestGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              MLService.baseUrl.split('//').last.split(':').first,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.forestGreen),
                            ),
                          ),
                          onTap: () => _showIPDialog(context),
                        ),
                        const Divider(height: 0),
                        _SettingsRow(
                          icon: Icons.storage_rounded,
                          label: 'Seed Test Data',
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
                          onTap: () async {
                            final auth = context.read<app_auth.AuthProvider>();
                            final uid = auth.firebaseUser?.uid;
                            final role = auth.userModel?.role;
                            if (uid != null && role != null) {
                              try {
                                await FirebaseService.seedDataForUser(uid, role);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('✅ Test data seeded successfully!')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('❌ Failed to seed: $e')),
                                  );
                                }
                              }
                            }
                          },
                        ),
                        const Divider(height: 0),
                        _SettingsRow(
                          icon: Icons.share_rounded,
                          label: 'My Impact Certificate',
                          trailing: const Icon(Icons.arrow_forward_ios_rounded,
                              size: 14, color: AppColors.textLight),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    '🎖️ Certificate generated! (screenshot package)'),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 0),
                        _SettingsRow(
                          icon: Icons.logout_rounded,
                          label: 'Sign Out',
                          iconColor: AppColors.riskHigh,
                          textColor: AppColors.riskHigh,
                          trailing: const SizedBox.shrink(),
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: const Text('Sign Out'),
                                content: const Text(
                                    'Are you sure you want to sign out?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text('Sign Out',
                                        style: TextStyle(
                                            color: AppColors.riskHigh)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && context.mounted) {
                              await context
                                  .read<app_auth.AuthProvider>()
                                  .signOut();
                              // Small delay to let state settle
                              await Future.delayed(const Duration(milliseconds: 100));
                              if (context.mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                      builder: (_) => const RoleSelectionScreen()),
                                  (route) => false,
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final UserRole role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (role) {
      case UserRole.ngo:
        color = AppColors.teal;
        label = 'NGO';
        break;
      case UserRole.volunteer:
        color = AppColors.purple;
        label = 'Volunteer';
        break;
      default:
        color = AppColors.amber;
        label = 'Donor';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _StatGridCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatGridCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowColor,
              blurRadius: 6,
              offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMedium,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final String icon;
  final String name;
  final int req;
  final int current;
  final bool earned;
  final Color color;

  const _BadgeTile({
    required this.icon,
    required this.name,
    required this.req,
    required this.current,
    required this.earned,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: earned ? color.withOpacity(0.1) : const Color(0xFFF5F2EF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: earned ? color.withOpacity(0.3) : const Color(0xFFE8E4DF),
          width: earned ? 1.5 : 1,
        ),
        boxShadow: earned
            ? [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(
              icon,
              style: TextStyle(
                fontSize: 22,
                color: earned ? null : const Color(0xFFBBB8B0),
              ),
            ),
            const Spacer(),
            if (earned)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '✓',
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ]),
          const Spacer(),
          Text(
            name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: earned ? color : AppColors.textLight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '$req deliveries',
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  final Color? iconColor;
  final Color? textColor;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.trailing,
    this.iconColor,
    this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: iconColor ?? AppColors.textMedium),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor ?? AppColors.textDark,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
