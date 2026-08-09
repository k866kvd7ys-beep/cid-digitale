import 'dart:async';

import 'package:cid_digitale/models/customer_legal_acceptance.dart';
import 'package:cid_digitale/models/customer_profile.dart';
import 'package:cid_digitale/services/customer_auth_service.dart';

class FakeCustomerAuthService implements CustomerAuthService {
  FakeCustomerAuthService({
    this.account,
    this.profile,
    this.signUpNeedsConfirmation = false,
    CustomerAuthState? initialAuthState,
  }) : initialAuthState = initialAuthState ??
            CustomerAuthState(
              event: CustomerAuthEventType.initialSession,
              hasSession: account != null,
            );

  CustomerAccount? account;
  CustomerProfile? profile;
  bool signUpNeedsConfirmation;
  CustomerAuthState initialAuthState;
  Object? loadProfileError;
  Object? signInError;
  Object? signUpError;
  Object? saveProfileError;
  Object? updatePasswordError;
  Completer<void>? signUpBlocker;
  bool? implicitRecoveryResult;
  int signInCalls = 0;
  int signUpCalls = 0;
  int signOutCalls = 0;
  int loadProfileCalls = 0;
  int saveProfileCalls = 0;
  int updatePasswordCalls = 0;
  String? lastLoadedProfileUserId;
  String? lastEmail;
  String? lastPassword;
  String? lastUpdatedPassword;
  CustomerLegalAcceptance? lastLegalAcceptance;
  CustomerLegalAcceptance? pendingLegalAcceptance;
  final List<CustomerLegalAcceptance> legalAcceptanceCalls = [];

  final StreamController<CustomerAuthState> _authController =
      StreamController<CustomerAuthState>.broadcast();

  @override
  CustomerAccount? get currentAccount => account;

  @override
  Stream<CustomerAuthState> get authStateChanges async* {
    yield initialAuthState;
    yield* _authController.stream;
  }

  void emitAuthState(CustomerAuthState state) {
    _authController.add(state);
  }

  @override
  Future<CustomerProfile?> loadProfile(String userId) async {
    loadProfileCalls++;
    lastLoadedProfileUserId = userId;
    if (loadProfileError case final error?) throw error;
    CustomerProfileAccessGuard.ensureOwner(account, userId);
    return profile;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    lastEmail = email;
  }

  @override
  Future<bool?> recoverPasswordSessionFromUrl(Uri uri) async {
    return implicitRecoveryResult;
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
    emitAuthState(
      const CustomerAuthState(
        event: CustomerAuthEventType.signedIn,
        hasSession: true,
      ),
    );
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    account = null;
    profile = null;
    emitAuthState(
      const CustomerAuthState(
        event: CustomerAuthEventType.signedOut,
        hasSession: false,
      ),
    );
  }

  @override
  Future<void> signOutPasswordRecovery() => signOut();

  @override
  Future<CustomerRegistrationResult> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required CustomerLegalAcceptance legalAcceptance,
  }) async {
    signUpCalls++;
    lastEmail = email;
    lastPassword = password;
    lastLegalAcceptance = legalAcceptance;
    legalAcceptanceCalls.add(legalAcceptance);
    await signUpBlocker?.future;
    if (signUpError case final error?) throw error;
    pendingLegalAcceptance = legalAcceptance;
    if (!signUpNeedsConfirmation) {
      account = CustomerAccount(
        id: 'customer-1',
        email: email,
        role: customerRole,
        firstName: firstName,
        lastName: lastName,
      );
      emitAuthState(
        const CustomerAuthState(
          event: CustomerAuthEventType.signedIn,
          hasSession: true,
        ),
      );
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
    final persistedAcceptance =
        profile?.legalAcceptance ?? pendingLegalAcceptance;
    profile = value.copyWith(legalAcceptance: persistedAcceptance);
    return profile!;
  }

  @override
  Future<void> updatePassword(String password) async {
    updatePasswordCalls++;
    lastUpdatedPassword = password;
    if (updatePasswordError case final error?) throw error;
    emitAuthState(
      const CustomerAuthState(
        event: CustomerAuthEventType.other,
        hasSession: true,
      ),
    );
  }

  Future<void> dispose() => _authController.close();
}
