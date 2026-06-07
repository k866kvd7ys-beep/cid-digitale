import 'package:cid_digitale/screens/service/workshop_slot_picker_screen.dart';
import 'package:cid_digitale/utils/service_booking_helper.dart';
import 'package:flutter/material.dart';

class ServiceAnmeldenScreen extends StatelessWidget {
  const ServiceAnmeldenScreen({super.key});

  String _locale(BuildContext context) =>
      Localizations.localeOf(context).languageCode;

  void _openBooking(
    BuildContext context,
    String locale,
    String serviceKey,
    String? cleaningProgram,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkshopSlotPickerScreen(
          title: workshopServiceLabel(locale, serviceKey),
          serviceType: 'service_anmelden',
          serviceSelectionKey: serviceKey,
          cleaningProgram: cleaningProgram,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = _locale(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          workshopServiceSelectionTitle(locale),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          itemCount: visibleWorkshopServiceKeys.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  workshopServiceSelectionSubtitle(locale),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B7280),
                    height: 1.45,
                  ),
                ),
              );
            }

            final serviceKey = visibleWorkshopServiceKeys[index - 1];
            return _ServiceOptionCard(
              icon: workshopServiceIcon(serviceKey),
              title: workshopServiceLabel(locale, serviceKey),
              description: workshopServiceDescription(locale, serviceKey),
              onTap: () {
                if (serviceKey == workshopServiceRepair) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _ServiceRepairInfoScreen(
                        onBookNow: (cleaningProgram) => _openBooking(
                          context,
                          locale,
                          serviceKey,
                          cleaningProgram,
                        ),
                      ),
                    ),
                  );
                  return;
                }

                _openBooking(context, locale, serviceKey, null);
              },
            );
          },
        ),
      ),
    );
  }
}

class _ServiceRepairInfoScreen extends StatefulWidget {
  const _ServiceRepairInfoScreen({required this.onBookNow});

  final ValueChanged<String> onBookNow;

  @override
  State<_ServiceRepairInfoScreen> createState() =>
      _ServiceRepairInfoScreenState();
}

class _ServiceRepairInfoScreenState extends State<_ServiceRepairInfoScreen> {
  String _selectedCleaningProgram = workshopCleaningProgramBasis;

  static const List<_ServiceRepairInfoItem> _items = [
    _ServiceRepairInfoItem(
      icon: Icons.search_outlined,
      title: 'Außenbereich,\nMotor und\nUnterboden',
      subtitle: 'Sichtkontrolle',
    ),
    _ServiceRepairInfoItem(
      icon: Icons.opacity_outlined,
      title: 'Flüssigkeiten',
      subtitle: 'Kontrolle, Ölwechsel (wenn fällig)',
    ),
    _ServiceRepairInfoItem(
      icon: Icons.fact_check_outlined,
      title: 'Bremsen und\nStossdämpfer',
      subtitle: 'Kontrolle und Messung auf dem Prüfstand (bei Bedarf)',
    ),
    _ServiceRepairInfoItem(
      icon: Icons.highlight_outlined,
      title: 'Beleuchtung',
      subtitle: 'Funktionskontrolle und Einstellung',
    ),
    _ServiceRepairInfoItem(
      icon: Icons.car_repair_outlined,
      title: 'Karosserie,\nFahrwerk,\nAufhängung',
      subtitle: 'Sichtkontrolle',
    ),
    _ServiceRepairInfoItem(
      icon: Icons.settings_outlined,
      title: 'Mechanik,\nGetriebe,\nMotor,\nAbgasanlage',
      subtitle: 'Sichtkontrolle',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Service und Reparaturarbeiten',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 960;
            final crossAxisCount = isDesktop ? 3 : 2;
            final outerPadding = isDesktop ? 28.0 : 16.0;
            final containerPadding = isDesktop ? 40.0 : 24.0;
            final gridSpacingX = isDesktop ? 60.0 : 24.0;
            final gridSpacingY = isDesktop ? 50.0 : 30.0;
            final mainAxisExtent = isDesktop ? 182.0 : 208.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                outerPadding,
                16,
                outerPadding,
                24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Container(
                    padding: EdgeInsets.all(containerPadding),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFEAEAEA),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Text(
                            'Was beinhaltet ein Autoservice bei uns',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 34),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _items.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: gridSpacingX,
                            mainAxisSpacing: gridSpacingY,
                            mainAxisExtent: mainAxisExtent,
                          ),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return _ServiceRepairInfoTile(item: item);
                          },
                        ),
                        const SizedBox(height: 40),
                        Text(
                          '🚘 Bei jedem Service ist ein Reinigung für Ihr Fahrzeug bereits inklusive Programm 1 basis',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFF4B5563),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Fahrzeugreinigung',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Wählen Sie das gewünschte Reinigungsprogramm',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF6B7280),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 18),
                        LayoutBuilder(
                          builder: (context, cleaningConstraints) {
                            final isMobile = cleaningConstraints.maxWidth < 900;
                            final itemWidth = isMobile
                                ? cleaningConstraints.maxWidth
                                : (cleaningConstraints.maxWidth - 32) / 3;

                            return Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                _CleaningProgramCard(
                                  width: itemWidth,
                                  icon: Icons.local_car_wash_outlined,
                                  title: 'PROGRAMM 1 BASIS',
                                  bullets: const [
                                    'bereits im Service inklusive',
                                    'schnelle Aussenreinigung',
                                    'Basis-Innenraumreinigung',
                                  ],
                                  badgeText: 'Inklusive',
                                  badgeColor: const Color(0xFF16A34A),
                                  selected: _selectedCleaningProgram ==
                                      workshopCleaningProgramBasis,
                                  onTap: () {
                                    setState(() {
                                      _selectedCleaningProgram =
                                          workshopCleaningProgramBasis;
                                    });
                                  },
                                ),
                                _CleaningProgramCard(
                                  width: itemWidth,
                                  icon: Icons.auto_awesome_outlined,
                                  title: 'PROGRAMM 2 COMFORT',
                                  bullets: const [
                                    'vollständige Aussenwäsche',
                                    'komplette Innenraumreinigung',
                                    'Innenfenster reinigen',
                                    'Cockpit reinigen',
                                  ],
                                  selected: _selectedCleaningProgram ==
                                      workshopCleaningProgramComfort,
                                  onTap: () {
                                    setState(() {
                                      _selectedCleaningProgram =
                                          workshopCleaningProgramComfort;
                                    });
                                  },
                                ),
                                _CleaningProgramCard(
                                  width: itemWidth,
                                  icon: Icons.workspace_premium_outlined,
                                  title: 'PROGRAMM 3 PREMIUM',
                                  bullets: const [
                                    'alles aus Programm 2',
                                    'Pflege der Innenkunststoffe',
                                    'schnelle Karosseriepolitur',
                                    'Innenraumduft',
                                    'Felgenreinigung',
                                  ],
                                  selected: _selectedCleaningProgram ==
                                      workshopCleaningProgramPremium,
                                  onTap: () {
                                    setState(() {
                                      _selectedCleaningProgram =
                                          workshopCleaningProgramPremium;
                                    });
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton(
                            onPressed: () =>
                                widget.onBookNow(_selectedCleaningProgram),
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: Text(
                              'Termin buchen',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ServiceRepairInfoTile extends StatelessWidget {
  const _ServiceRepairInfoTile({required this.item});

  final _ServiceRepairInfoItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          item.icon,
          color: const Color(0xFF334155),
          size: 40,
        ),
        const SizedBox(height: 12),
        Text(
          item.title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
            height: 1.28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          item.subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            color: const Color(0xFF6B7280),
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _CleaningProgramCard extends StatelessWidget {
  const _CleaningProgramCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.bullets,
    required this.selected,
    required this.onTap,
    this.badgeText,
    this.badgeColor,
  });

  final double width;
  final IconData icon;
  final String title;
  final List<String> bullets;
  final bool selected;
  final VoidCallback onTap;
  final String? badgeText;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFE5E7EB),
                width: selected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.035),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        icon,
                        color: const Color(0xFF1D4ED8),
                        size: 24,
                      ),
                    ),
                    const Spacer(),
                    if (badgeText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: (badgeColor ?? const Color(0xFF16A34A))
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badgeText!,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: badgeColor ?? const Color(0xFF16A34A),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
                for (final bullet in bullets) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Icon(
                          Icons.circle,
                          size: 6,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          bullet,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF4B5563),
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (bullet != bullets.last) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceRepairInfoItem {
  const _ServiceRepairInfoItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class _ServiceOptionCard extends StatelessWidget {
  const _ServiceOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFEAEAEA),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFF2563EB), size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                        height: 1.25,
                      ),
                    ),
                    if (description.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6B7280),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
