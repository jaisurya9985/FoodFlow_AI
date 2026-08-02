import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/app_colors.dart';

class ShimmerLoadingList extends StatelessWidget {
  const ShimmerLoadingList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ShimmerCard()
              .animate(delay: Duration(milliseconds: 100 * i))
              .fadeIn(duration: 400.ms),
        ),
      ),
    );
  }
}

class _ShimmerCard extends StatefulWidget {
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1E3D2E), width: 1),
          ),
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end: Alignment(_anim.value + 1, 0),
              colors: [
                AppColors.darkCardAlt,
                AppColors.darkCardAlt.withValues(alpha: 0.4),
                AppColors.darkCardAlt,
              ],
            ).createShader(bounds),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.darkCardAlt, borderRadius: BorderRadius.circular(14))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(height: 14, width: double.infinity, decoration: BoxDecoration(color: AppColors.darkCardAlt, borderRadius: BorderRadius.circular(6))),
                          const SizedBox(height: 6),
                          Container(height: 11, width: 120, decoration: BoxDecoration(color: AppColors.darkCardAlt, borderRadius: BorderRadius.circular(6))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(height: 11, width: 200, decoration: BoxDecoration(color: AppColors.darkCardAlt, borderRadius: BorderRadius.circular(6))),
              ],
            ),
          ),
        );
      },
    );
  }
}
