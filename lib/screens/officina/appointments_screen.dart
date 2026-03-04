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

  Future<List<dynamic>> _load() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final res = await _sb
        .from('workshop_appointments')
        .select('*')
        .eq('workshop_id', widget.workshopId)
        .gte('start_time', now)
        .order('start_time', ascending: true);
    return res as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kalender')),
      body: FutureBuilder<List<dynamic>>(
        future: _load(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty) return const Center(child: Text('Keine Termine'));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = items[i] as Map<String, dynamic>;
              final start = DateTime.parse(r['start_time'] as String).toLocal();
              final end = DateTime.parse(r['end_time'] as String).toLocal();
              final type = (r['service_type'] as String) == 'raeder_sommer' ? 'Sommer' : 'Winter';

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
                        '${_df.format(start)}  ${_tf.format(start)} - ${_tf.format(end)}   •   $type',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
