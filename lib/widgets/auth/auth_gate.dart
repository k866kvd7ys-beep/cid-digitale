import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../screens/auth/login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.homeBuilder});

  final WidgetBuilder homeBuilder;

  @override
  Widget build(BuildContext context) {
    // WEB: richiede sessione; MOBILE: bypassa (comportamento attuale)
    if (kIsWeb) {
      return StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = Supabase.instance.client.auth.currentSession;
          if (session == null) return const LoginPage();
          return homeBuilder(context);
        },
      );
    }

    return homeBuilder(context);
  }
}
