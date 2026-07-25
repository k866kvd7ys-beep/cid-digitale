import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/customer_profile.dart';

const String customerRole = 'customer';
const String customerPasswordRecoveryPath = '/reset-password';
const String customerPasswordRecoveryRedirectUrl =
    'https://cid-client.vercel.app$customerPasswordRecoveryPath';

bool isExistingAuthAccountSignUpResponse(AuthResponse response) {
  return response.session == null && response.user?.identities?.isEmpty == true;
}

enum CustomerAuthEventType {
  initialSession,
  passwordRecovery,
  signedIn,
  signedOut,
  other,
}

class CustomerAuthState {
  const CustomerAuthState({
    required this.event,
    required this.hasSession,
  });

  final CustomerAuthEventType event;
  final bool hasSession;

  bool get isPasswordRecovery =>
      event == CustomerAuthEventType.passwordRecovery;
}

class CustomerAccount {
  const CustomerAccount({
    required this.id,
    required this.email,
    required this.role,
    this.firstName = '',
    this.lastName = '',
  });

  final String id;
  final String email;
  final String role;
  final String firstName;
  final String lastName;

  bool get isCustomer => role == customerRole;
}

class CustomerRegistrationResult {
  const CustomerRegistrationResult({
    required this.hasSession,
    required this.emailConfirmationRequired,
  });

  final bool hasSession;
  final bool emailConfirmationRequired;
}

enum CustomerAuthErrorCode {
  invalidCredentials,
  emailNotConfirmed,
  emailAlreadyRegistered,
  weakPassword,
  rateLimited,
  notCustomer,
  unauthenticated,
  profileUnavailable,
  generic,
}

class CustomerAuthException implements Exception {
  const CustomerAuthException(this.code, [this.details]);

  final CustomerAuthErrorCode code;
  final String? details;

  @override
  String toString() => 'CustomerAuthException($code, $details)';
}

abstract class CustomerAuthService {
  CustomerAccount? get currentAccount;

  Stream<CustomerAuthState> get authStateChanges;

  Future<CustomerRegistrationResult> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  });

  Future<void> signIn({
    required String email,
    required String password,
  });

  Future<void> sendPasswordReset(String email);

  Future<bool?> recoverPasswordSessionFromUrl(Uri uri);

  Future<void> updatePassword(String password);

  Future<void> signOutPasswordRecovery();

  Future<void> signOut();

  Future<CustomerProfile?> loadProfile(String userId);

  Future<CustomerProfile> saveProfile(CustomerProfile profile);
}

class CustomerProfileAccessGuard {
  const CustomerProfileAccessGuard._();

  static void ensureOwner(CustomerAccount? account, String userId) {
    if (account == null || account.id != userId) {
      throw const CustomerAuthException(CustomerAuthErrorCode.unauthenticated);
    }
  }
}

class SupabaseCustomerAuthService implements CustomerAuthService {
  SupabaseCustomerAuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  CustomerAccount? get currentAccount =>
      _accountFromUser(_client.auth.currentUser);

  @override
  Stream<CustomerAuthState> get authStateChanges {
    return _client.auth.onAuthStateChange.map((state) {
      return CustomerAuthState(
        event: switch (state.event) {
          AuthChangeEvent.initialSession =>
            CustomerAuthEventType.initialSession,
          AuthChangeEvent.passwordRecovery =>
            CustomerAuthEventType.passwordRecovery,
          AuthChangeEvent.signedIn => CustomerAuthEventType.signedIn,
          AuthChangeEvent.signedOut => CustomerAuthEventType.signedOut,
          _ => CustomerAuthEventType.other,
        },
        hasSession: state.session != null,
      );
    });
  }

  @override
  Future<CustomerRegistrationResult> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {
          'role': customerRole,
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
        },
      );
      if (isExistingAuthAccountSignUpResponse(response)) {
        throw const CustomerAuthException(
          CustomerAuthErrorCode.emailAlreadyRegistered,
        );
      }
      return CustomerRegistrationResult(
        hasSession: response.session != null,
        emailConfirmationRequired: response.session == null,
      );
    } on AuthException catch (error) {
      throw _translateAuthException(error);
    }
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final account = _accountFromUser(response.user);
      if (account == null) {
        throw const CustomerAuthException(
          CustomerAuthErrorCode.unauthenticated,
        );
      }
    } on CustomerAuthException {
      rethrow;
    } on AuthException catch (error) {
      throw _translateAuthException(error);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    final recoveryAuthClient = GoTrueClient(
      url: '$supabaseUrl/auth/v1',
      headers: {
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer $supabaseAnonKey',
      },
      autoRefreshToken: false,
      flowType: AuthFlowType.implicit,
    );
    try {
      await recoveryAuthClient.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: customerPasswordRecoveryRedirectUrl,
      );
    } on AuthException catch (error) {
      throw _translateAuthException(error);
    } finally {
      recoveryAuthClient.dispose();
    }
  }

  @override
  Future<bool?> recoverPasswordSessionFromUrl(Uri uri) async {
    if (uri.queryParameters.containsKey('error') ||
        uri.fragment.contains('error_description=')) {
      return false;
    }
    if (uri.fragment.isEmpty) return null;

    late final Map<String, String> fragmentParameters;
    try {
      fragmentParameters = Uri.splitQueryString(uri.fragment);
    } on FormatException {
      return false;
    }
    if (fragmentParameters['type'] != 'recovery') return null;

    final refreshToken = fragmentParameters['refresh_token'];
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final response = await _client.auth.setSession(refreshToken);
      return response.session != null;
    } on AuthException {
      return false;
    }
  }

  @override
  Future<void> updatePassword(String password) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(password: password),
      );
    } on AuthException catch (error) {
      throw _translateAuthException(error);
    }
  }

  @override
  Future<void> signOutPasswordRecovery() async {
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } on AuthException catch (error) {
      throw _translateAuthException(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (error) {
      throw _translateAuthException(error);
    }
  }

  @override
  Future<CustomerProfile?> loadProfile(String userId) async {
    final account = currentAccount;
    CustomerProfileAccessGuard.ensureOwner(account, userId);

    try {
      final response = await _client
          .from('customer_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (response == null) return null;
      return CustomerProfile.fromMap(response);
    } catch (error) {
      throw CustomerAuthException(
        CustomerAuthErrorCode.profileUnavailable,
        error.toString(),
      );
    }
  }

  @override
  Future<CustomerProfile> saveProfile(CustomerProfile profile) async {
    final account = currentAccount;
    CustomerProfileAccessGuard.ensureOwner(account, profile.userId);

    try {
      final response = await _client
          .from('customer_profiles')
          .upsert(profile.toUpsertMap(), onConflict: 'user_id')
          .select()
          .single();
      return CustomerProfile.fromMap(response);
    } catch (error) {
      throw CustomerAuthException(
        CustomerAuthErrorCode.profileUnavailable,
        error.toString(),
      );
    }
  }

  CustomerAccount? _accountFromUser(User? user) {
    if (user == null) return null;
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    return CustomerAccount(
      id: user.id,
      email: user.email ?? '',
      role: metadata['role']?.toString() ?? '',
      firstName: metadata['first_name']?.toString() ?? '',
      lastName: metadata['last_name']?.toString() ?? '',
    );
  }

  CustomerAuthException _translateAuthException(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return CustomerAuthException(
        CustomerAuthErrorCode.invalidCredentials,
        error.message,
      );
    }
    if (message.contains('email not confirmed')) {
      return CustomerAuthException(
        CustomerAuthErrorCode.emailNotConfirmed,
        error.message,
      );
    }
    if (message.contains('already registered') ||
        message.contains('already been registered') ||
        message.contains('user already exists')) {
      return CustomerAuthException(
        CustomerAuthErrorCode.emailAlreadyRegistered,
        error.message,
      );
    }
    if (message.contains('password') &&
        (message.contains('weak') || message.contains('least'))) {
      return CustomerAuthException(
        CustomerAuthErrorCode.weakPassword,
        error.message,
      );
    }
    if (message.contains('rate limit') || error.statusCode == '429') {
      return CustomerAuthException(
        CustomerAuthErrorCode.rateLimited,
        error.message,
      );
    }
    return CustomerAuthException(
      CustomerAuthErrorCode.generic,
      error.message,
    );
  }
}
