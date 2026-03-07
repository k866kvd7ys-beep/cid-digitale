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
        .filter('status', 'in', '(pending,confirmed)')
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

          DateTime? _parseStart(Map<String, dynamic> r) {
            final dateStr = r['appointment_date']?.toString() ?? '';
            final timeRaw = r['appointment_time']?.toString() ?? '00:00:00';
            final timeStr = timeRaw.length == 5 ? '$timeRaw:00' : timeRaw;
            return DateTime.tryParse('${dateStr}T$timeStr');
          }

          DateTime? _parseEnd(Map<String, dynamic> r, DateTime? start) {
            if (start == null) return null;
            final durationMinutes =
                (r['duration_minutes'] as num?)?.toInt() ?? 60;
            return start.add(Duration(minutes: durationMinutes));
          }

          final statuses = items
              .map((r) => (r['status'] ?? '').toString())
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

          final firstStart = _parseStart(items.first);
          final lastStart = _parseStart(items.last);
          final firstLabel = firstStart != null
              ? '${_df.format(firstStart.toLocal())} ${_tf.format(firstStart.toLocal())}'
              : 'n/d';
          final lastLabel = lastStart != null
              ? '${_df.format(lastStart.toLocal())} ${_tf.format(lastStart.toLocal())}'
              : 'n/d';

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Text(
                  'DEBUG WORKSHOP CALENDAR\n'
                  'recordsCount: ${items.length}\n'
                  'statuses: ${statuses.join(', ')}\n'
                  'firstAppointment: $firstLabel\n'
                  'lastAppointment: $lastLabel\n'
                  'source: appointment_requests',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final r = items[i];

                    final start = _parseStart(r)?.toLocal();
                    final end = _parseEnd(r, start);
                    final type = (r['service_type'] ?? '').toString();

                    if (start == null) {
                      return const SizedBox.shrink();
                    }

                    final startLabel =
                        '${_df.format(start)}  ${_tf.format(start)}';
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
