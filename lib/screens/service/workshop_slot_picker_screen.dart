import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/services/appointment_requests_service.dart';

class WorkshopSlotPickerScreen extends StatefulWidget {
  final String title; // UI title
  final String
      serviceType; // 'raeder_sommer' | 'raeder_winter' | 'service_anmelden'
  final String? damageType;

  const WorkshopSlotPickerScreen({
    super.key,
    required this.title,
    required this.serviceType,
    this.damageType,
  });

  @override
  State<WorkshopSlotPickerScreen> createState() =>
      _WorkshopSlotPickerScreenState();
}

class _WorkshopSlotPickerScreenState extends State<WorkshopSlotPickerScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  DateTime? _selectedSlot;
  bool _loading = false;
  bool _submitting = false;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _appointmentService = AppointmentRequestsService();

  bool _isTaken(DateTime slot) => false;

  Widget _licensePlateCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: theme.colorScheme.primary.withOpacity(0.12),
            ),
            child: Icon(Icons.confirmation_number_outlined,
                color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.license_plate_label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.70),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _plateCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: AppLocalizations.of(context)!.license_plate_hint,
                    border: InputBorder.none,
                  ),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _premiumFieldDec(BuildContext context, String hint) {
    final theme = Theme.of(context);
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: theme.colorScheme.surface.withOpacity(0.22),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.35)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
            color: theme.colorScheme.primary.withOpacity(0.6), width: 1.2),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _plateCtrl.dispose();
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

  Future<void> _loadAvailableSlots(DateTime day) async {
    // Placeholder for future async loading; rebuild to reflect selected day.
    setState(() {});
  }

  Future<void> _onBookPressed() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Name eingeben')),
      );
      return;
    }
    final plate = _plateCtrl.text.trim();
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

    setState(() {
      _loading = true;
      _submitting = true;
    });

    final slotStr = DateFormat('dd.MM.yyyy HH:mm').format(_selectedSlot!);

    try {
      final locale = Localizations.localeOf(context).languageCode;
      await _appointmentService.createRequest(
        serviceType: widget.serviceType,
        damageType: widget.damageType,
        appointmentDate: _selectedSlot,
        appointmentTime: DateFormat('HH:mm:ss').format(_selectedSlot!),
        durationMinutes: 60,
        customerName: _nameCtrl.text,
        phone: _phoneCtrl.text,
        email: _emailCtrl.text,
        licensePlate: _plateCtrl.text,
        notes: null,
        locale: locale,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Termin gesendet ($slotStr)')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Errore invio: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final df = DateFormat('EEE, dd.MM.yyyy');
    final tf = DateFormat('HH:mm');

    final slots = _buildSlots(_selectedDay);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Termin auswählen'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // HEADER
                      Text(widget.title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      _licensePlateCard(context),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration:
                            _premiumFieldDec(context, 'Name und Nachname'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _phoneCtrl,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.phone,
                              decoration: _premiumFieldDec(context, 'Telefon'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _emailCtrl,
                              textInputAction: TextInputAction.done,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _premiumFieldDec(context, 'E-Mail'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

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

                      const SizedBox(height: 12),
                      Text(df.format(_selectedDay),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      Text(
                        'Bitte Uhrzeit auswählen',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),

                      if (slots.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context)
                                  .dividerColor
                                  .withOpacity(0.35),
                            ),
                          ),
                          child: const Text('Keine Uhrzeiten verfügbar'),
                        )
                      else
                        Wrap(
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

                            return ChoiceChip(
                              label: Text(
                                tf.format(slot),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              selected: selected,
                              onSelected: taken
                                  ? null
                                  : (_) {
                                      setState(() => _selectedSlot = slot);
                                    },
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                              selectedColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.18),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surface
                                  .withOpacity(0.22),
                              labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              side: BorderSide(
                                color: Theme.of(context)
                                    .dividerColor
                                    .withOpacity(0.35),
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading || _submitting ? null : _onBookPressed,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
              child: Text(
                _loading || _submitting ? '...' : l10n.termin_buchen,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
