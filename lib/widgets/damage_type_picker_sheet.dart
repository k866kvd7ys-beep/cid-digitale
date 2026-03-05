import 'package:flutter/material.dart';

enum DamageType {
  glass,
  hail,
  marten,
  parking,
  comprehensive,
}

typedef DamageTypeLabel = String Function(DamageType type);

class DamageTypePickerSheet extends StatelessWidget {
  const DamageTypePickerSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.cancelText,
    required this.types,
    required this.iconFor,
    required this.labelFor,
    required this.onSelected,
    this.selectedDamageType,
  });

  final String title;
  final String subtitle;
  final String cancelText;
  final List<DamageType> types;
  final IconData Function(DamageType type) iconFor;
  final DamageTypeLabel labelFor;
  final ValueChanged<DamageType> onSelected;
  final DamageType? selectedDamageType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 12.0;
                final itemWidth = (constraints.maxWidth - spacing) / 2;
                final itemHeight = itemWidth * 0.55;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: types.map((t) {
                    final selected = t == selectedDamageType;
                    return SizedBox(
                      width: itemWidth,
                      height: itemHeight,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => onSelected(t),
                        child: Ink(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: selected
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surface,
                            border: Border.all(
                              color: selected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant,
                              width: selected ? 1.6 : 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  iconFor(t),
                                  size: 34,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  labelFor(t),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child:
                    Text(MaterialLocalizations.of(context).cancelButtonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
