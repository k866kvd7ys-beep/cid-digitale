import 'package:flutter/material.dart';

import '../models/workshop_model.dart';

class PreferredWorkshopCard extends StatelessWidget {
  const PreferredWorkshopCard({
    super.key,
    required this.title,
    required this.workshop,
    required this.emptyMessage,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    required this.openLabel,
    required this.closedLabel,
    required this.statusUnavailableLabel,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.busy = false,
  });

  final String title;
  final WorkshopModel? workshop;
  final String emptyMessage;
  final String primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final String openLabel;
  final String closedLabel;
  final String statusUnavailableLabel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final selectedWorkshop = workshop;
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE7F5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                child: const Icon(
                  Icons.home_repair_service_rounded,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (selectedWorkshop == null)
            Text(
              emptyMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
            )
          else ...[
            Text(
              selectedWorkshop.name,
              key: const Key('preferred_workshop_name'),
              style: theme.textTheme.titleLarge?.copyWith(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.location_on_outlined,
              value: _valueOrDash(
                [
                  selectedWorkshop.address.trim(),
                  selectedWorkshop.city.trim(),
                ].where((part) => part.isNotEmpty).join(', '),
              ),
            ),
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.phone_outlined,
              value: _valueOrDash(selectedWorkshop.phone),
            ),
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.alternate_email_rounded,
              value: _valueOrDash(selectedWorkshop.email),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.star_rounded,
                  label: selectedWorkshop.rating?.toStringAsFixed(1) ?? '—',
                  color: const Color(0xFFF59E0B),
                  background: const Color(0xFFFFF7ED),
                ),
                _InfoChip(
                  icon: Icons.schedule_rounded,
                  label: switch (selectedWorkshop.isOpen) {
                    true => openLabel,
                    false => closedLabel,
                    null => statusUnavailableLabel,
                  },
                  color: selectedWorkshop.isOpen == true
                      ? const Color(0xFF15803D)
                      : const Color(0xFF64748B),
                  background: selectedWorkshop.isOpen == true
                      ? const Color(0xFFECFDF3)
                      : const Color(0xFFF1F5F9),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: busy ? null : onPrimaryAction,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    selectedWorkshop == null
                        ? Icons.search_rounded
                        : Icons.check_circle_outline_rounded,
                  ),
            label: Text(
              primaryActionLabel,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (secondaryActionLabel != null && onSecondaryAction != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : onSecondaryAction,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: const Color(0xFFB91C1C),
                side: const BorderSide(color: Color(0xFFFECACA)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(
                secondaryActionLabel!,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _valueOrDash(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? '—' : normalized;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: const Color(0xFF64748B)),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF334155),
                  height: 1.35,
                ),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
