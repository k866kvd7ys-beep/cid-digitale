import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppointmentsScreen extends StatefulWidget {
  final String workshopId;
  const AppointmentsScreen({super.key, required this.workshopId});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final _sb = Supabase.instance.client;
  final _df = DateFormat('dd.MM.yyyy');
  final _tf = DateFormat('HH:mm');

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await _sb
        .from('appointment_requests')
        .select('*')
        .neq('status', 'cancelled')
        .order('appointment_date', ascending: true)
        .order('appointment_time', ascending: true)
        .limit(500);
    return (res as List).cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kalender')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _load(),
        builder: (context, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty) return const Center(child: Text('Keine Termine'));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = items[i];

              final dateStr = r['appointment_date']?.toString() ?? '';
              final timeStr = r['appointment_time']?.toString() ?? '00:00:00';
              final combined = DateTime.tryParse('${dateStr}T$timeStr');
              final start = combined?.toLocal();
              final durationMinutes =
                  (r['duration_minutes'] as num?)?.toInt() ?? 60;
              final end = start?.add(Duration(minutes: durationMinutes));
              final type = (r['service_type'] ?? '').toString();

              if (start == null) {
                return const SizedBox.shrink();
              }

              final startLabel = '${_df.format(start)}  ${_tf.format(start)}';
              final endLabel = end != null ? _tf.format(end) : '';

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black26),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$startLabel - $endLabel   •   $type',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
