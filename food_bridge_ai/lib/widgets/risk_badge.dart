import 'package:flutter/material.dart';
import '../models/donation_model.dart';
import '../utils/app_colors.dart';

class RiskBadge extends StatelessWidget {
  final RiskLabel risk;
  const RiskBadge({super.key, required this.risk});

  Color get _color {
    switch (risk) {
      case RiskLabel.high: return AppColors.riskHigh;
      case RiskLabel.medium: return AppColors.riskMedium;
      case RiskLabel.low: return AppColors.riskLow;
    }
  }

  String get _label {
    switch (risk) {
      case RiskLabel.high: return '⚠ High Risk';
      case RiskLabel.medium: return '◈ Medium';
      case RiskLabel.low: return '✓ Fresh';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.4), width: 1),
        boxShadow: [BoxShadow(color: _color.withValues(alpha: 0.15), blurRadius: 8)],
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _color,
        ),
      ),
    );
  }
}
