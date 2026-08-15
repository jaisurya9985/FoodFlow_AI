import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:uuid/uuid.dart';
import '../../models/donation_model.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/donation_provider.dart';
import '../../services/location_service.dart';
import '../../services/weather_service.dart';
import '../../utils/app_colors.dart';

class DonationForm extends StatefulWidget {
  const DonationForm({super.key});

  @override
  State<DonationForm> createState() => _DonationFormState();
}

class _DonationFormState extends State<DonationForm> {
  int _step = 0;
  final PageController _pageController = PageController();
  late ConfettiController _confettiCtrl;

  // Step 1
  final _titleCtrl = TextEditingController();
  FoodCategory _category = FoodCategory.cookedMeal;
  double _quantityKg = 5.0;
  final _descCtrl = TextEditingController();

  // Step 2
  double? _storageTemp;
  bool _fetchingWeather = false;
  double _maxFridgeDays = 3.0;
  double _timeSinceCooked = 0.0;
  bool _requiresVehicle = false;
  Map<String, dynamic>? _riskResult;

  // Step 3
  double _pickupLat = 13.05;
  double _pickupLng = 80.21;
  final _addressCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  bool _fetchingLocation = false;

  bool get _isLastStep => _step == 2;

  @override
  void initState() {
    super.initState();
    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _confettiCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    if (_step == 0) {
      if (_titleCtrl.text.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a food title')),
        );
        return;
      }
      setState(() => _step = 1);
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      if (_storageTemp == null && !_fetchingWeather) {
        _fetchWeather();
      }
    } else if (_step == 1) {
      if (_riskResult == null) {
        await _predictRisk();
      }

      if (_riskResult != null && _riskResult!['risk'] == 3) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ This food has exceeded safe freshness limits and cannot be donated.'),
            backgroundColor: AppColors.riskHigh,
            duration: Duration(seconds: 4),
          ),
        );
        return; // Block progression
      }

      setState(() => _step = 2);
      _pageController.animateToPage(
        2,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      await _submit();
    }
  }

  Future<void> _predictRisk() async {
    final prov = context.read<DonationProvider>();
    final result = await prov.predictRisk(
      category: _category.apiValue,
      storageTemperatureC: _storageTemp ?? 28.0,
      maxFridgeDays: _maxFridgeDays,
      timeSinceCooked: _timeSinceCooked,
    );
    if (mounted) {
      setState(() => _riskResult = result);
    }
  }

  Future<void> _fetchWeather() async {
    setState(() => _fetchingWeather = true);
    final pos = await LocationService.getCurrentPosition();
    if (pos != null) {
      if (mounted) {
        setState(() {
          _pickupLat = pos.latitude;
          _pickupLng = pos.longitude;
          _addressCtrl.text =
              '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        });
      }
      final temp = await WeatherService.getCurrentTemperature(
          pos.latitude, pos.longitude);
      if (temp != null && mounted) {
        setState(() {
          _storageTemp = temp;
          _fetchingWeather = false;
        });
        return;
      }
    }
    // Fallback if location/weather fails
    if (mounted) {
      setState(() {
        _storageTemp = 28.0; // Assume 28°C
        _fetchingWeather = false;
      });
    }
    await _predictRisk();
  }

  Future<void> _submit() async {
    final auth = context.read<app_auth.AuthProvider>();
    final prov = context.read<DonationProvider>();
    final user = auth.userModel;

    final String finalDonorId = user?.uid ?? 'guest_donor_123';
    final String finalDonorName = user?.name ?? 'Guest Donor';

    final risk = _riskResult;
    int riskScore = 1;
    RiskLabel riskLabel = RiskLabel.medium;
    int expiryMins = 240;

    if (risk != null) {
      riskScore = risk['risk'] as int;
      expiryMins = (risk['expiry_minutes'] as num?)?.toInt() ?? 240;
      
      riskLabel = riskScore == 2
          ? RiskLabel.high
          : riskScore == 1
              ? RiskLabel.medium
              : RiskLabel.low;
    }

    debugPrint('Creating DonationModel...');
    final donation = DonationModel(
      id: const Uuid().v4(),
      donorId: finalDonorId,
      donorName: finalDonorName,
      title: _titleCtrl.text.trim(),
      category: _category,
      quantityKg: _quantityKg,
      storageTemperatureC: _storageTemp ?? 28.0,
      maxFridgeDays: _maxFridgeDays,
      timeSinceCooked: _timeSinceCooked,
      description: _descCtrl.text.trim(),
      pickupLocation: PickupLocation(
        lat: _pickupLat,
        lng: _pickupLng,
        address: _addressCtrl.text.trim().isNotEmpty
            ? _addressCtrl.text.trim()
            : 'Chennai, Tamil Nadu',
      ),
      status: DonationStatus.available,
      riskLabel: riskLabel,
      riskScore: riskScore,
      expiryMinutes: expiryMins,
      expiresAt: DateTime.now().add(Duration(minutes: expiryMins)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    debugPrint('Calling prov.postDonation...');
    final id = await prov.postDonation(donation);
    debugPrint('postDonation returned $id');

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (id != null) {
      _confettiCtrl.play();
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
            content: Text('🎉 Donation posted! We\'ll find a match soon.')),
      );
      navigator.pop();
    } else {
      debugPrint('Showing error snackbar');
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to post donation.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DonationProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0A06),
      appBar: AppBar(
        backgroundColor: const Color(0xFF140C05),
        elevation: 0,
        title: const Row(children: [
          Text('🍱', style: TextStyle(fontSize: 20)),
          SizedBox(width: 10),
          Text(
            'Post Surplus Food',
            style: TextStyle(color: Color(0xFFF0E0D0), fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ]),
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFFFF8C42)),
                onPressed: () {
                  setState(() => _step--);
                  _pageController.animateToPage(
                    _step,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              )
            : IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFFFF8C42)),
                onPressed: () => Navigator.of(context).pop(),
              ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(
                    ['🌾 Food Details', '🌡️ Safety Check', '📍 Pickup Location'][_step],
                    style: const TextStyle(fontSize: 12, color: Color(0xFFBB8860), fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text('${_step + 1} / 3',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF5A4030), fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / 3,
                    minHeight: 6,
                    backgroundColor: const Color(0xFF2C1A0A),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF8C42)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background warmth blobs
          Positioned(
            top: -60, right: -60,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [const Color(0xFFFF7043).withOpacity(0.1), Colors.transparent]),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _Step1(
                      titleCtrl: _titleCtrl,
                      descCtrl: _descCtrl,
                      category: _category,
                      quantityKg: _quantityKg,
                      onCategoryChanged: (c) => setState(() => _category = c),
                      onQtyChanged: (q) => setState(() => _quantityKg = q),
                    ),
                    _Step2(
                      storageTemp: _storageTemp,
                      fetchingWeather: _fetchingWeather,
                      maxFridgeDays: _maxFridgeDays,
                      timeSinceCooked: _timeSinceCooked,
                      requiresVehicle: _requiresVehicle,
                      riskResult: _riskResult,
                      onFridgeChanged: (v) => setState(() { _maxFridgeDays = v; }),
                      onCookedChanged: (v) => setState(() => _timeSinceCooked = v),
                      onVehicleChanged: (v) => setState(() => _requiresVehicle = v),
                      onInteractionEnd: _predictRisk,
                    ),
                    _Step3(
                      addressCtrl: _addressCtrl,
                      instructionsCtrl: _instructionsCtrl,
                      fetchingLocation: _fetchingLocation,
                      onGetLocation: () async {
                        setState(() => _fetchingLocation = true);
                        final pos = await LocationService.getCurrentPosition();
                        if (pos != null) {
                          setState(() {
                            _pickupLat = pos.latitude;
                            _pickupLng = pos.longitude;
                            _addressCtrl.text =
                                '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
                          });
                        }
                        setState(() => _fetchingLocation = false);
                      },
                    ),
                  ],
                ),
              ),

              // Bottom button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: GestureDetector(
                  onTap: prov.isLoading ? null : _nextStep,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: prov.isLoading
                          ? const LinearGradient(colors: [Color(0xFF3A2010), Color(0xFF3A2010)])
                          : _isLastStep
                              ? const LinearGradient(
                                  colors: [Color(0xFFFF6B2C), Color(0xFFFFB300)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                )
                              : const LinearGradient(
                                  colors: [Color(0xFFFF7043), Color(0xFFFF8C42)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: prov.isLoading ? [] : [
                        BoxShadow(
                          color: const Color(0xFFFF7043).withOpacity(0.45),
                          blurRadius: 20, offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: prov.isLoading
                          ? const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white70),
                            )
                          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(
                                _isLastStep ? 'Submit Donation' : 'Continue',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.2),
                              ),
                              const SizedBox(width: 8),
                              Text(_isLastStep ? '🎉' : '→', style: const TextStyle(fontSize: 18)),
                            ]),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiCtrl,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 30,
              colors: const [
                Color(0xFFFF8C42),
                Color(0xFFFFD166),
                Color(0xFFFF6B6B),
                Color(0xFFFF7043),
                Colors.white,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step1 extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final FoodCategory category;
  final double quantityKg;
  final ValueChanged<FoodCategory> onCategoryChanged;
  final ValueChanged<double> onQtyChanged;

  const _Step1({
    required this.titleCtrl,
    required this.descCtrl,
    required this.category,
    required this.quantityKg,
    required this.onCategoryChanged,
    required this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFFFF8C42), Color(0xFFFFD166)],
            ).createShader(b),
            child: const Text(
              'What are you donating?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3),
            ),
          ).animate().fadeIn().slideY(begin: 0.2, end: 0),
          const SizedBox(height: 4),
          const Text(
            'Tell us about the food you\'re sharing',
            style: TextStyle(fontSize: 13, color: Color(0xFF8A6F5A)),
          ),
          const SizedBox(height: 24),

          // Title field
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF160C04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF3A2010)),
            ),
            child: TextField(
              controller: titleCtrl,
              style: const TextStyle(color: Color(0xFFF0E0D0)),
              decoration: const InputDecoration(
                labelText: 'Food Title',
                labelStyle: TextStyle(color: Color(0xFF8A6F5A)),
                hintText: 'e.g. Chicken Biryani, Fresh Vegetables',
                hintStyle: TextStyle(color: Color(0xFF5A4030)),
                prefixIcon: Icon(Icons.fastfood_outlined, size: 20, color: Color(0xFFFF8C42)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Category label
          const Row(children: [
            Icon(Icons.category_rounded, size: 14, color: Color(0xFFFF8C42)),
            SizedBox(width: 6),
            Text('Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFF0E0D0))),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: FoodCategory.values.map((c) {
              final sel = c == category;
              return GestureDetector(
                onTap: () => onCategoryChanged(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: sel
                        ? const LinearGradient(colors: [Color(0xFFFF7043), Color(0xFFFF8C42)])
                        : null,
                    color: sel ? null : const Color(0xFF1A0F06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: sel ? const Color(0xFFFF8C42) : const Color(0xFF3A2010)),
                    boxShadow: sel ? [BoxShadow(color: const Color(0xFFFF7043).withOpacity(0.35), blurRadius: 10)] : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(c.icon, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        c.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : const Color(0xFF8A6F5A),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Quantity
          Row(
            children: [
              const Row(children: [
                Icon(Icons.scale_rounded, size: 14, color: Color(0xFFFF8C42)),
                SizedBox(width: 6),
                Text('Quantity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFF0E0D0))),
              ]),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF160C04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3A2010)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18, color: Color(0xFFFF8C42)),
                      onPressed: () { if (quantityKg > 1) onQtyChanged(quantityKg - 1); },
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(
                        '${quantityKg.toStringAsFixed(0)} kg',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFFF8C42)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18, color: Color(0xFFFF8C42)),
                      onPressed: () => onQtyChanged(quantityKg + 1),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Description
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF160C04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF3A2010)),
            ),
            child: TextField(
              controller: descCtrl,
              maxLines: 3,
              style: const TextStyle(color: Color(0xFFF0E0D0)),
              decoration: const InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: Color(0xFF8A6F5A)),
                hintText: 'Any additional details about this food...',
                hintStyle: TextStyle(color: Color(0xFF5A4030)),
                alignLabelWithHint: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _Step2 extends StatelessWidget {
  final double? storageTemp;
  final bool fetchingWeather;
  final double maxFridgeDays;
  final double timeSinceCooked;
  final bool requiresVehicle;
  final Map<String, dynamic>? riskResult;
  final ValueChanged<double> onFridgeChanged;
  final ValueChanged<double> onCookedChanged;
  final ValueChanged<bool> onVehicleChanged;
  final VoidCallback onInteractionEnd;

  const _Step2({
    required this.storageTemp,
    required this.fetchingWeather,
    required this.maxFridgeDays,
    required this.timeSinceCooked,
    required this.requiresVehicle,
    this.riskResult,
    required this.onFridgeChanged,
    required this.onCookedChanged,
    required this.onVehicleChanged,
    required this.onInteractionEnd,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFFFF8C42), Color(0xFFFFD166)],
            ).createShader(b),
            child: const Text(
              'Storage & Safety',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Our AI uses this to assess food safety 🤖',
            style: TextStyle(fontSize: 13, color: Color(0xFF8A6F5A)),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF160C04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF3A2010)),
            ),
            child: Row(
              children: [
                const Icon(Icons.thermostat_rounded, color: Color(0xFFFF8C42)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Storage Temp (Auto-detected)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFF0E0D0)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fetchingWeather
                            ? 'Detecting local weather...'
                            : storageTemp != null
                                ? 'Auto-detected from your location'
                                : 'Fallback: 28.0°C',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF8A6F5A)),
                      ),
                    ],
                  ),
                ),
                if (fetchingWeather)
                  const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF8C42)),
                  )
                else
                  Text(
                    '${(storageTemp ?? 28.0).toStringAsFixed(1)}°C',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFFFF8C42)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _SliderField(
            label: 'Max Fridge Days (Shelf Life)',
            unit: ' days',
            value: maxFridgeDays,
            min: 0, max: 30,
            onChanged: onFridgeChanged,
            onChangeEnd: (_) => onInteractionEnd(),
            activeColor: const Color(0xFFFF8C42),
          ),
          const SizedBox(height: 20),

          _SliderField(
            label: 'Time Since Cooked',
            unit: ' hrs',
            value: timeSinceCooked,
            min: 0, max: 72,
            onChanged: onCookedChanged,
            onChangeEnd: (_) => onInteractionEnd(),
            activeColor: timeSinceCooked > 8
                ? AppColors.riskHigh
                : timeSinceCooked > 4
                    ? AppColors.riskMedium
                    : const Color(0xFFFF8C42),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF160C04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF3A2010)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Requires Vehicle',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFF0E0D0))),
                      Text('Heavy loads over 20 kg',
                          style: TextStyle(fontSize: 12, color: Color(0xFF8A6F5A))),
                    ],
                  ),
                ),
                Switch(
                  value: requiresVehicle,
                  onChanged: onVehicleChanged,
                  activeColor: Colors.white,
                  activeTrackColor: const Color(0xFFFF8C42),
                  inactiveTrackColor: const Color(0xFF2C1A0A),
                  trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                ),
              ],
            ),
          ),

          if (riskResult != null) ...[
            const SizedBox(height: 20),
            _RiskResultCard(riskResult: riskResult!)
                .animate().slideY(begin: 0.3, end: 0, duration: 400.ms).fadeIn(duration: 300.ms),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _SliderField extends StatelessWidget {
  final String label;
  final String unit;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final Color activeColor;

  const _SliderField({
    required this.label,
    required this.unit,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onChangeEnd,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFF0E0D0))),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: activeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: activeColor.withOpacity(0.3)),
            ),
            child: Text(
              '${value.toStringAsFixed(1)}$unit',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: activeColor),
            ),
          ),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: activeColor,
            thumbColor: activeColor,
            inactiveTrackColor: const Color(0xFF2C1A0A),
            overlayColor: activeColor.withOpacity(0.12),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }
}


class _RiskResultCard extends StatelessWidget {
  final Map<String, dynamic> riskResult;

  const _RiskResultCard({required this.riskResult});

  @override
  Widget build(BuildContext context) {
    final riskInt = riskResult['risk'] as int;
    final label = riskResult['risk_label'] as String;
    final confidence = (riskResult['confidence'] as num).toDouble().round();

    Color bg;
    Color text;
    IconData icon;
    String message;

    switch (riskInt) {
      case 3:
        bg = AppColors.riskHigh.withOpacity(0.9);
        text = Colors.white;
        icon = Icons.coronavirus_rounded;
        message = 'This food is spoiled and unsafe for donation.';
        break;
      case 2:
        bg = AppColors.riskHigh;
        text = Colors.white;
        icon = Icons.warning_rounded;
        message = 'Urgent pickup needed! Must be delivered as soon as possible.';
        break;
      case 1:
        bg = AppColors.riskMedium;
        text = Colors.white;
        icon = Icons.schedule_rounded;
        message = 'Moderate urgency. Delivery target: please deliver quickly.';
        break;
      default:
        bg = AppColors.riskLow;
        text = Colors.white;
        icon = Icons.check_circle_rounded;
        message = 'Food is stable. Safe to deliver in a meanwhile.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: text, size: 22),
            const SizedBox(width: 8),
            Text(
              'Risk Level: $label',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: text,
              ),
            ),
            const Spacer(),
            Text(
              '$confidence% sure',
              style: TextStyle(
                fontSize: 12,
                color: text.withOpacity(0.8),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              color: text.withOpacity(0.9),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Step3 extends StatelessWidget {
  final TextEditingController addressCtrl;
  final TextEditingController instructionsCtrl;
  final bool fetchingLocation;
  final VoidCallback onGetLocation;

  const _Step3({
    required this.addressCtrl,
    required this.instructionsCtrl,
    required this.fetchingLocation,
    required this.onGetLocation,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFFFF8C42), Color(0xFFFFD166)],
            ).createShader(b),
            child: const Text(
              'Pickup Location',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Where should the volunteer collect from?',
            style: TextStyle(fontSize: 13, color: Color(0xFF8A6F5A)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton.icon(
              onPressed: fetchingLocation ? null : onGetLocation,
              icon: fetchingLocation
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF8C42)))
                  : const Icon(Icons.my_location_rounded, color: Color(0xFFFF8C42)),
              label: Text(
                fetchingLocation ? 'Getting location...' : 'Use My Current Location',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFFF8C42)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFF7043), width: 1.5),
                backgroundColor: const Color(0xFF1A0F06),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Row(children: [
            Expanded(child: Divider(color: Color(0xFF2C1A0A))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('or enter manually',
                  style: TextStyle(fontSize: 12, color: Color(0xFF5A4030))),
            ),
            Expanded(child: Divider(color: Color(0xFF2C1A0A))),
          ]),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF160C04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF3A2010)),
            ),
            child: TextField(
              controller: addressCtrl,
              style: const TextStyle(color: Color(0xFFF0E0D0)),
              decoration: const InputDecoration(
                labelText: 'Pickup Address',
                labelStyle: TextStyle(color: Color(0xFF8A6F5A)),
                hintText: 'Street, Area, City',
                hintStyle: TextStyle(color: Color(0xFF5A4030)),
                prefixIcon: Icon(Icons.location_on_outlined, size: 20, color: Color(0xFFFF8C42)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF160C04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF3A2010)),
            ),
            child: TextField(
              controller: instructionsCtrl,
              maxLines: 3,
              style: const TextStyle(color: Color(0xFFF0E0D0)),
              decoration: const InputDecoration(
                labelText: 'Special Instructions',
                labelStyle: TextStyle(color: Color(0xFF8A6F5A)),
                hintText: 'e.g. Call on arrival, Use back entrance...',
                hintStyle: TextStyle(color: Color(0xFF5A4030)),
                alignLabelWithHint: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
