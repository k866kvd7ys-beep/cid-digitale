import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class WorkshopSlotPickerScreen extends StatefulWidget {
  final String title; // UI title
  final String serviceType; // 'raeder_sommer' | 'raeder_winter' | 'service_anmelden'

  const WorkshopSlotPickerScreen({
    super.key,
    required this.title,
    required this.serviceType,
  });

  @override
  State<WorkshopSlotPickerScreen> createState() => _WorkshopSlotPickerScreenState();
}

class _WorkshopSlotPickerScreenState extends State<WorkshopSlotPickerScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  DateTime? _selectedSlot;
  bool _loading = false;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // OFFLINE DEMO: slot occupati in memoria (per serviceType)
  static final Map<String, Set<String>> _bookedByService = {};

  String _slotKey(DateTime dt) {
    final d = DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);
    return d.toIso8601String();
  }

  bool _isTaken(DateTime slot) {
    return _bookedByService[widget.serviceType]?.contains(_slotKey(slot)) ?? false;
  }

  void _markTaken(DateTime slot) {
    final set = _bookedByService.putIfAbsent(widget.serviceType, () => <String>{});
    set.add(_slotKey(slot));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // Orari officina: 08:00-18:00 ogni 30 min
  List<DateTime> _buildSlots(DateTime day) {
    final base = DateTime(day.year, day.month, day.day);
    final slots = <DateTime>[];
    for (int h = 8; h < 18; h++) {
      slots.add(base.add(Duration(hours: h, minutes: 0)));
      slots.add(base.add(Duration(hours: h, minutes: 30)));
    }
    return slots;
  }

  Future<void> _bookOffline() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Name eingeben')),
      );
      return;
    }
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Uhrzeit auswählen')),
      );
      return;
    }
    if (_isTaken(_selectedSlot!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dieser Termin ist bereits belegt.')),
      );
      return;
    }

    setState(() => _loading = true);

    // OFFLINE: finta chiamata rete
    await Future.delayed(const Duration(milliseconds: 500));

    _markTaken(_selectedSlot!);

    final slotStr = DateFormat('dd.MM.yyyy HH:mm').format(_selectedSlot!);
    debugPrint(
      'BOOK OFFLINE -> ${widget.serviceType} | $slotStr | $name | ${_phoneCtrl.text.trim()} | ${_emailCtrl.text.trim()}',
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      _selectedSlot = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Termin gespeichert (offline): $slotStr')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEE, dd.MM.yyyy');
    final tf = DateFormat('HH:mm');

    final slots = _buildSlots(_selectedDay);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Termin auswählen'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),

                  // DATI CLIENTE
                  TextField(
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Name und Nachname',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _phoneCtrl,
                          textInputAction: TextInputAction.next,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Telefon',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _emailCtrl,
                          textInputAction: TextInputAction.done,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'E-Mail',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // CALENDARIO
            TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 120)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                  _selectedSlot = null;
                });
              },
            ),

            // DATA
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(df.format(_selectedDay), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),

            // SLOT "PILLOLE" (GRID)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: slots.map((slot) {
                    final taken = _isTaken(slot);
                    final selected = _selectedSlot != null &&
                        _selectedSlot!.year == slot.year &&
                        _selectedSlot!.month == slot.month &&
                        _selectedSlot!.day == slot.day &&
                        _selectedSlot!.hour == slot.hour &&
                        _selectedSlot!.minute == slot.minute;

                    final bg = taken
                        ? Colors.black12
                        : (selected ? Colors.blue.shade100 : Colors.white);

                    final border = taken
                        ? Colors.black12
                        : (selected ? Colors.blue : Colors.black26);

                    return InkWell(
                      onTap: taken
                          ? null
                          : () {
                              setState(() => _selectedSlot = slot);
                            },
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tf.format(slot),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: taken ? Colors.black45 : Colors.black,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              taken ? 'Belegt' : (selected ? '✓' : ''),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: taken ? Colors.black45 : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _bookOffline,
              child: Text(_loading ? '...' : 'Termin buchen'),
            ),
          ),
        ),
      ),
    );
  }
}
