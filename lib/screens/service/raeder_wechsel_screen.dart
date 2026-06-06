import 'package:cid_digitale/utils/tire_service_type_helper.dart';
import 'package:flutter/material.dart';

import 'workshop_slot_picker_screen.dart';

const String _completeWheelImageUrl =
    'https://images.unsplash.com/photo-1619642751034-765dfdf7c58e?auto=format&fit=crop&w=1600&q=85';
const String _tireOnlyImageUrl =
    'https://images.unsplash.com/photo-1606220838315-056192d5e927?auto=format&fit=crop&w=1600&q=85';

class RaederWechselScreen extends StatefulWidget {
  const RaederWechselScreen({super.key});

  @override
  State<RaederWechselScreen> createState() => _RaederWechselScreenState();
}

class _RaederWechselScreenState extends State<RaederWechselScreen> {
  bool? _summerSelected;

  String get _locale => tireLocaleCode(context);
  bool get _showSeasonStep => _summerSelected == null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          tireSeasonGroupTitle(_locale),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _showSeasonStep
              ? _SeasonSelectionStep(
                  key: const ValueKey('season-step'),
                  locale: _locale,
                  onSelectSeason: (summer) {
                    setState(() => _summerSelected = summer);
                  },
                )
              : _TireTypeSelectionStep(
                  key: ValueKey('service-step-${_summerSelected!}'),
                  locale: _locale,
                  summer: _summerSelected!,
                  onBack: () {
                    setState(() => _summerSelected = null);
                  },
                  onSelectType: _openBookingFlow,
                ),
        ),
      ),
    );
  }

  void _openBookingFlow(String tireServiceType) {
    final summer = isSummerTireServiceType(tireServiceType);
    final serviceType = summer ? 'raeder_sommer' : 'raeder_winter';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkshopSlotPickerScreen(
          title: tireOptionTitle(_locale, tireServiceType),
          serviceType: serviceType,
          tireServiceType: tireServiceType,
        ),
      ),
    );
  }
}

class _SeasonSelectionStep extends StatelessWidget {
  const _SeasonSelectionStep({
    super.key,
    required this.locale,
    required this.onSelectSeason,
  });

  final String locale;
  final ValueChanged<bool> onSelectSeason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tireSeasonGroupTitle(locale),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            tireStepSubtitle(locale),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6B7280),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          _SeasonChoiceCard(
            emoji: '☀️',
            title: tireSeasonCardTitle(locale, summer: true),
            subtitle: tireSeasonCardSubtitle(locale, summer: true),
            accent: const Color(0xFFF28C48),
            onTap: () => onSelectSeason(true),
          ),
          const SizedBox(height: 16),
          _SeasonChoiceCard(
            emoji: '❄️',
            title: tireSeasonCardTitle(locale, summer: false),
            subtitle: tireSeasonCardSubtitle(locale, summer: false),
            accent: const Color(0xFF4B7BFF),
            onTap: () => onSelectSeason(false),
          ),
        ],
      ),
    );
  }
}

class _TireTypeSelectionStep extends StatelessWidget {
  const _TireTypeSelectionStep({
    super.key,
    required this.locale,
    required this.summer,
    required this.onBack,
    required this.onSelectType,
  });

  final String locale;
  final bool summer;
  final VoidCallback onBack;
  final ValueChanged<String> onSelectType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completeType = summer
        ? tireServiceSummerCompleteWheels
        : tireServiceWinterCompleteWheels;
    final tiresOnlyType =
        summer ? tireServiceSummerTiresOnly : tireServiceWinterTiresOnly;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        final cards = [
          Expanded(
            child: _TireOptionCard(
              imageUrl: _completeWheelImageUrl,
              title: tireOptionTitle(locale, completeType),
              description: tireOptionDescription(locale, completeType),
              accent:
                  summer ? const Color(0xFFF28C48) : const Color(0xFF4B7BFF),
              onTap: () => onSelectType(completeType),
            ),
          ),
          Expanded(
            child: _TireOptionCard(
              imageUrl: _tireOnlyImageUrl,
              title: tireOptionTitle(locale, tiresOnlyType),
              description: tireOptionDescription(locale, tiresOnlyType),
              accent:
                  summer ? const Color(0xFFF28C48) : const Color(0xFF4B7BFF),
              onTap: () => onSelectType(tiresOnlyType),
            ),
          ),
        ];

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(tireBackToSeasonLabel(locale)),
              ),
              const SizedBox(height: 6),
              Text(
                tireStepTitle(locale, summer: summer),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                tireStepSubtitle(locale),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    cards[0],
                    const SizedBox(width: 18),
                    cards[1],
                  ],
                )
              else ...[
                cards[0],
                const SizedBox(height: 18),
                cards[1],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SeasonChoiceCard extends StatelessWidget {
  const _SeasonChoiceCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFEAEAEA), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.chevron_right_rounded, color: accent, size: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _TireOptionCard extends StatelessWidget {
  const _TireOptionCard({
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.accent,
    required this.onTap,
  });

  final String imageUrl;
  final String title;
  final String description;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFEAEAEA), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.network(
                  imageUrl,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF4B5563),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    tireContinueLabel(tireLocaleCode(context)),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF111827),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, color: accent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
