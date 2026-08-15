import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/donation_provider.dart';
import '../utils/app_colors.dart';

class RateVolunteerButton extends StatefulWidget {
  final String volunteerId;
  final String volunteerName;
  final String donationId;
  final bool isAlreadyRated;

  const RateVolunteerButton({
    super.key,
    required this.volunteerId,
    required this.volunteerName,
    required this.donationId,
    this.isAlreadyRated = false,
  });

  @override
  State<RateVolunteerButton> createState() => _RateVolunteerButtonState();
}

class _RateVolunteerButtonState extends State<RateVolunteerButton> {
  bool _rated = false;

  @override
  void initState() {
    super.initState();
    _rated = widget.isAlreadyRated;
  }

  @override
  void didUpdateWidget(covariant RateVolunteerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAlreadyRated != oldWidget.isAlreadyRated) {
      _rated = widget.isAlreadyRated;
    }
  }

  void _showRatingDialog() {
    double selectedRating = 5.0;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Rate ${widget.volunteerName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How was the delivery service?'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < selectedRating ? Icons.star : Icons.star_border,
                      color: AppColors.amber,
                      size: 32,
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () {
                            setDialogState(() => selectedRating = index + 1.0);
                          },
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: Colors.black,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final prov = context.read<DonationProvider>();

                      final success = await prov.rateVolunteer(
                        volunteerId: widget.volunteerId,
                        rating: selectedRating,
                        donationId: widget.donationId,
                      );

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }

                      if (mounted) {
                        if (success) {
                          setState(() => _rated = true);
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Thank you for rating the volunteer!'),
                              backgroundColor: AppColors.riskLow,
                            ),
                          );
                        } else {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Failed to submit rating. Please try again.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_rated || widget.isAlreadyRated) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.riskLow.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.riskLow.withOpacity(0.35), width: 1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: AppColors.riskLow, size: 13),
            SizedBox(width: 4),
            Text(
              'Rated ✓',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.riskLow,
              ),
            ),
          ],
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: _showRatingDialog,
      icon: const Icon(Icons.star_rounded, size: 14),
      label: const Text('Rate', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        backgroundColor: AppColors.amber.withOpacity(0.2),
        foregroundColor: AppColors.amber,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.amber.withOpacity(0.4)),
        ),
      ),
    );
  }
}
