import 'dart:async';

import 'package:cid_digitale/models/customer_profile.dart';
import 'package:cid_digitale/services/customer_auth_service.dart';

class FakeCustomerAuthService implements CustomerAuthService {
  FakeCustomerAuthService({
    this.account,
    this.profile,
    this.signUpNeedsConfirmation = false,
  });

  CustomerAccount? account;
  CustomerProfile? profile;
  bool signUpNeedsConfirmation;
  Object? loadProfileError;
  Object? signInError;
  Object? saveProfileError;
  int signInCalls = 0;
  int signOutCalls = 0;
  int loadProfileCalls = 0;
  int saveProfileCalls = 0;
  String? lastEmail;
  String? lastPassword;

  final StreamController<void> _authController =
      StreamController<void>.broadcast();

  @override
  CustomerAccount? get currentAccount => account;

  @override
  Stream<void> get authStateChanges => _authController.stream;

  @override
  Future<CustomerProfile?> loadProfile(String userId) async {
    loadProfileCalls++;
    if (loadProfileError case final error?) throw error;
    CustomerProfileAccessGuard.ensureOwner(account, userId);
    return profile;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    lastEmail = email;
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    lastEmail = email;
    lastPassword = password;
    if (signInError case final error?) throw error;
    account ??= CustomerAccount(
      id: 'customer-1',
      email: email,
      role: customerRole,
      firstName: 'Mario',
      lastName: 'Rossi',
    );
    _authController.add(null);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    account = null;
    profile = null;
    _authController.add(null);
  }

  @override
  Future<CustomerRegistrationResult> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    lastEmail = email;
    lastPassword = password;
    if (!signUpNeedsConfirmation) {
      account = CustomerAccount(
        id: 'customer-1',
        email: email,
        role: customerRole,
        firstName: firstName,
        lastName: lastName,
      );
      _authController.add(null);
    }
    return CustomerRegistrationResult(
      hasSession: !signUpNeedsConfirmation,
      emailConfirmationRequired: signUpNeedsConfirmation,
    );
  }

  @override
  Future<CustomerProfile> saveProfile(CustomerProfile value) async {
    saveProfileCalls++;
    if (saveProfileError case final error?) throw error;
    CustomerProfileAccessGuard.ensureOwner(account, value.userId);
    profile = value;
    return value;
  }

  Future<void> dispose() => _authController.close();
}
