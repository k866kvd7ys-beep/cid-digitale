import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';

class RaederWechselScreen extends StatelessWidget {
  const RaederWechselScreen({super.key});

  Future<void> _openCalendar(BuildContext context,
      {required String title}) async {
    // default: fra 2 giorni alle 09:00, durata 30 min (modifica se vuoi)
    final now = DateTime.now();
    final start =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 2, hours: 9));
    final end = start.add(const Duration(minutes: 30));

    final event = Event(
      title: title,
      description: 'Räderwechsel Termin',
      location: '', // opzionale
      startDate: start,
      endDate: end,
      allDay: false,
      iosParams: const IOSParams(
        reminder: Duration(minutes: 60), // 1h prima
      ),
      androidParams: const AndroidParams(
        emailInvites: [], // opzionale
      ),
    );

    await Add2Calendar.addEvent2Cal(event);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Räder wechsel')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _OptionTile(
              title: 'Räder wechsel Sommer',
              icon: Icons.wb_sunny_outlined,
              onTap: () => _openCalendar(context, title: 'Räder wechsel Sommer'),
            ),
            const SizedBox(height: 12),
            _OptionTile(
              title: 'Räder wechsel Winter',
              icon: Icons.ac_unit_outlined,
              onTap: () => _openCalendar(context, title: 'Räder wechsel Winter'),
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
