import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'workshop_slot_picker_screen.dart';

class RaederWechselScreen extends StatelessWidget {
  const RaederWechselScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.raeder_wechsel_title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _OptionTile(
              title: l10n.raeder_wechsel_sommer,
              icon: Icons.wb_sunny_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const WorkshopSlotPickerScreen(
                      title: 'Räder wechsel Sommer',
                      serviceType: 'raeder_sommer',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _OptionTile(
              title: l10n.raeder_wechsel_winter,
              icon: Icons.ac_unit_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const WorkshopSlotPickerScreen(
                      title: 'Räder wechsel Winter',
                      serviceType: 'raeder_winter',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _OptionTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black26),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
