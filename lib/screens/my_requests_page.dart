import 'package:flutter/material.dart';
import 'package:cid_digitale/l10n/app_localizations.dart';

class MyRequestsPage extends StatelessWidget {
  const MyRequestsPage({super.key, required this.incidentsTab});

  final Widget incidentsTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.my_requests_title),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.tab_appointments),
              Tab(text: l10n.tab_incidents),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AppointmentsPlaceholder(emptyText: l10n.empty_appointments),
            incidentsTab,
          ],
        ),
      ),
    );
  }
}

class _AppointmentsPlaceholder extends StatelessWidget {
  const _AppointmentsPlaceholder({required this.emptyText});

  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        emptyText,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
            ),
      ),
    );
  }
}
