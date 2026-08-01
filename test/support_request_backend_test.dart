import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/20260801123000_create_support_requests.sql',
  ).readAsStringSync();
  final edgeFunction = File(
    'supabase/functions/send-support-request-notification/index.ts',
  ).readAsStringSync();

  test('migration creates only the dedicated support data structures', () {
    expect(migration, contains('create table public.support_requests'));
    expect(
        migration,
        contains(
            'alter table public.support_requests enable row level security'));
    expect(migration, contains('auth.uid() = created_by'));
    expect(
        migration,
        contains(
            'grant select, insert on table public.support_requests to authenticated'));
    expect(migration, isNot(contains('grant update')));
    expect(migration, isNot(contains('grant delete')));
    expect(migration, contains("'support-attachments'"));
    expect(migration, contains('false,\n  5242880'));
    expect(
        migration, contains("array['image/jpeg', 'image/png', 'image/webp']"));
    expect(
      migration,
      contains("(storage.foldername(name))[1] = auth.uid()::text"),
    );
  });

  test(
      'notification function authenticates ownership and keeps secrets server-side',
      () {
    expect(edgeFunction, contains('Deno.env.get("SUPPORT_EMAIL")'));
    expect(edgeFunction, contains('Deno.env.get("RESEND_API_KEY")'));
    expect(edgeFunction, contains('await supabase.auth.getUser(token)'));
    expect(edgeFunction, contains('.eq("created_by", user.id)'));
    expect(edgeFunction, contains('timeZone: "Europe/Zurich"'));
    expect(edgeFunction, contains('to: [SUPPORT_EMAIL]'));
    expect(edgeFunction, contains('reply_to: replyEmail'));
    expect(edgeFunction, contains('attachments,'));
    expect(edgeFunction, isNot(contains('service_role_key:')));
  });

  test(
      'existing email functions are not referenced or modified by support flow',
      () {
    expect(edgeFunction, isNot(contains('send-cid-email')));
    expect(edgeFunction, isNot(contains('send-appointment-confirmation')));
    expect(edgeFunction, isNot(contains('send-insurance-information-request')));
  });
}
