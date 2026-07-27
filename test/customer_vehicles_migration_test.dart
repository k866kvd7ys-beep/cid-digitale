import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260727130000_create_customer_vehicles.sql';
  late String sql;

  setUpAll(() {
    sql = File(migrationPath).readAsStringSync().toLowerCase();
  });

  test('customer vehicles schema contains every existing app field', () {
    for (final column in [
      'user_id',
      'vehicle_id',
      'plate',
      'brand',
      'model',
      'vin',
      'mileage',
      'first_registration',
      'insurance_company',
      'policy_number',
      'claim_number',
      'is_primary',
      'created_at',
      'updated_at',
    ]) {
      expect(sql, contains(column));
    }
    expect(
      sql,
      contains('references public.customer_profiles (user_id)'),
    );
    expect(sql, contains('primary key (user_id, vehicle_id)'));
  });

  test('RLS isolates select insert update and delete by auth uid', () {
    expect(
      sql,
      contains(
          'alter table public.customer_vehicles enable row level security'),
    );
    for (final operation in ['select', 'insert', 'update', 'delete']) {
      expect(
        sql,
        contains('customer_vehicles_${operation}_own'),
      );
    }
    expect(
      '(select auth.uid()) = user_id'.allMatches(sql),
      hasLength(greaterThanOrEqualTo(5)),
    );
    expect(
      sql,
      contains(
        'grant select, insert, update, delete\n'
        'on table public.customer_vehicles\n'
        'to authenticated',
      ),
    );
    expect(
      sql,
      contains('revoke all on table public.customer_vehicles from anon'),
    );
  });

  test('primary and delete functions are invoker-only and owner-scoped', () {
    expect(sql, isNot(contains('security definer')));
    expect(
      'security invoker'.allMatches(sql),
      hasLength(greaterThanOrEqualTo(4)),
    );
    expect(
      "set search_path = ''".allMatches(sql),
      hasLength(greaterThanOrEqualTo(4)),
    );
    expect(sql, contains('set_customer_primary_vehicle'));
    expect(sql, contains('delete_customer_vehicle'));
    expect(sql, contains('user_id = (select auth.uid())'));
    expect(
      sql,
      contains(
        'grant execute\n'
        'on function public.set_customer_primary_vehicle(text)\n'
        'to authenticated',
      ),
    );
    expect(
      sql,
      contains(
        'grant execute\n'
        'on function public.delete_customer_vehicle(text)\n'
        'to authenticated',
      ),
    );
  });

  test('database guarantees first and single primary with oldest fallback', () {
    expect(
      sql,
      contains('customer_vehicles_one_primary_per_user'),
    );
    expect(sql, contains('where is_primary'));
    expect(sql, contains('set_first_customer_vehicle_primary'));
    expect(sql, contains('new.is_primary = true'));
    expect(sql, contains('order by created_at, vehicle_id'));
    expect(sql, contains('set is_primary = true'));
  });
}
