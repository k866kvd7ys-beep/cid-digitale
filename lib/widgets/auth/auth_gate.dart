import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/recovery_browser_path.dart';
import '../../auth/customer_auth_strings.dart';
import '../../models/customer_profile.dart';
import '../../screens/auth/customer_profile_page.dart';
import '../../screens/auth/forgot_password_page.dart';
import '../../screens/auth/login_page.dart';
import '../../screens/auth/password_recovery_page.dart';
import '../../services/customer_auth_service.dart';
import 'auth_page_shell.dart';

typedef AuthenticatedHomeBuilder = Widget Function(
  BuildContext context,
  CustomerProfile profile,
  CustomerAuthService service,
);

enum AuthGateStatus {
  loading,
  signedOut,
  profileRequired,
  authenticated,
  passwordRecovery,
  passwordRecoveryInvalid,
  forgotPassword,
  error,
}

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.homeBuilder,
    this.service,
    this.passwordRecoveryRoute,
    this.onLocaleSelected,
  });

  final AuthenticatedHomeBuilder homeBuilder;
  final CustomerAuthService? service;
  final bool? passwordRecoveryRoute;
  final ValueChanged<String>? onLocaleSelected;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final CustomerAuthService _service;
  StreamSubscription<CustomerAuthState>? _authSubscription;
  AuthGateStatus _status = AuthGateStatus.loading;
  CustomerAccount? _account;
  CustomerProfile? _profile;
  Object? _error;
  Object? _signedOutError;
  late bool _isPasswordRecoveryRoute;
  bool _checkingPasswordRecoveryCallback = false;
  bool _completingPasswordRecovery = false;
  bool _showPasswordUpdatedMessage = false;
  CustomerAuthState? _pendingAuthState;
  int _resolution = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SupabaseCustomerAuthService();
    _isPasswordRecoveryRoute =
        widget.passwordRecoveryRoute ?? isCustomerPasswordRecoveryLocation();
    _checkingPasswordRecoveryCallback = _isPasswordRecoveryRoute;
    _authSubscription = _service.authStateChanges.listen(
      _handleAuthState,
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          if (_isPasswordRecoveryRoute) {
            _checkingPasswordRecoveryCallback = false;
            _status = AuthGateStatus.passwordRecoveryInvalid;
            _error = null;
          } else {
            _status = AuthGateStatus.error;
            _error = error;
          }
        });
      },
    );
    if (_isPasswordRecoveryRoute) {
      unawaited(_initializePasswordRecoveryRoute());
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _handleAuthState(CustomerAuthState state) {
    if (state.isPasswordRecovery) {
      if (!mounted) return;
      setState(() {
        _isPasswordRecoveryRoute = true;
        _checkingPasswordRecoveryCallback = false;
        _pendingAuthState = null;
        _account = null;
        _profile = null;
        _error = null;
        _signedOutError = null;
        _showPasswordUpdatedMessage = false;
        _status = state.hasSession
            ? AuthGateStatus.passwordRecovery
            : AuthGateStatus.passwordRecoveryInvalid;
      });
      return;
    }

    if (_isPasswordRecoveryRoute) {
      if (_checkingPasswordRecoveryCallback) {
        _pendingAuthState = state;
        return;
      }
      if (_completingPasswordRecovery ||
          (_status == AuthGateStatus.passwordRecovery &&
              state.event != CustomerAuthEventType.signedOut)) {
        return;
      }
      if (!mounted) return;
      setState(() {
        _status = AuthGateStatus.passwordRecoveryInvalid;
        _error = null;
      });
      return;
    }

    unawaited(_resolveAuthState());
  }

  Future<void> _initializePasswordRecoveryRoute() async {
    bool? recovered;
    try {
      recovered = await _service.recoverPasswordSessionFromUrl(Uri.base);
    } catch (_) {
      recovered = false;
    }
    if (!mounted ||
        (!_checkingPasswordRecoveryCallback &&
            _status == AuthGateStatus.passwordRecovery)) {
      return;
    }

    _checkingPasswordRecoveryCallback = false;
    if (recovered == true) {
      clearCustomerPasswordRecoveryCredentials();
      setState(() {
        _pendingAuthState = null;
        _account = null;
        _profile = null;
        _error = null;
        _signedOutError = null;
        _status = AuthGateStatus.passwordRecovery;
      });
      return;
    }
    if (recovered == false) {
      setState(() {
        _pendingAuthState = null;
        _status = AuthGateStatus.passwordRecoveryInvalid;
        _error = null;
      });
      return;
    }

    final pendingState = _pendingAuthState;
    _pendingAuthState = null;
    if (pendingState != null) {
      _handleAuthState(pendingState);
    }
  }

  Future<void> _resolveAuthState() async {
    final resolution = ++_resolution;
    if (mounted) {
      setState(() {
        _status = AuthGateStatus.loading;
        _error = null;
      });
    }

    final account = _service.currentAccount;
    if (account == null) {
      if (!mounted || resolution != _resolution) return;
      setState(() {
        _account = null;
        _profile = null;
        _status = AuthGateStatus.signedOut;
      });
      return;
    }

    _signedOutError = null;
    try {
      final profile = await _service.loadProfile(account.id);
      if (!mounted || resolution != _resolution) return;
      setState(() {
        _account = account;
        _profile = profile;
        _status = profile?.profileCompleted == true
            ? AuthGateStatus.authenticated
            : AuthGateStatus.profileRequired;
      });
    } catch (error) {
      if (!mounted || resolution != _resolution) return;
      setState(() {
        _account = account;
        _profile = null;
        _status = AuthGateStatus.error;
        _error = error;
      });
    }
  }

  void _profileSaved(CustomerProfile profile) {
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _status = AuthGateStatus.authenticated;
      _error = null;
    });
  }

  Future<void> _logout() async {
    setState(() {
      _status = AuthGateStatus.loading;
      _error = null;
    });
    try {
      await _service.signOut();
      if (!mounted) return;
      setState(() {
        _account = null;
        _profile = null;
        _status = AuthGateStatus.signedOut;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = AuthGateStatus.error;
        _error = error;
      });
    }
  }

  Future<void> _completePasswordRecovery() async {
    _completingPasswordRecovery = true;
    try {
      await _service.signOutPasswordRecovery();
      if (!mounted) return;
      leaveCustomerPasswordRecoveryLocation();
      setState(() {
        _isPasswordRecoveryRoute = false;
        _completingPasswordRecovery = false;
        _showPasswordUpdatedMessage = true;
        _account = null;
        _profile = null;
        _error = null;
        _signedOutError = null;
        _status = AuthGateStatus.signedOut;
      });
    } catch (_) {
      _completingPasswordRecovery = false;
      rethrow;
    }
  }

  void _requestNewRecoveryEmail() {
    leaveCustomerPasswordRecoveryLocation();
    setState(() {
      _isPasswordRecoveryRoute = false;
      _showPasswordUpdatedMessage = false;
      _error = null;
      _signedOutError = null;
      _status = AuthGateStatus.forgotPassword;
    });
  }

  void _returnToLogin() {
    if (!mounted) return;
    setState(() {
      _status = AuthGateStatus.signedOut;
      _error = null;
      _signedOutError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case AuthGateStatus.loading:
        return const _AuthLoadingPage();
      case AuthGateStatus.signedOut:
        return LoginPage(
          service: _service,
          onLocaleSelected: widget.onLocaleSelected,
          initialError: _signedOutError,
          initialSuccessMessage: _showPasswordUpdatedMessage
              ? CustomerAuthStrings.of(context).passwordUpdated
              : null,
          onAuthenticated: _resolveAuthState,
        );
      case AuthGateStatus.profileRequired:
        return CustomerProfilePage(
          service: _service,
          account: _account!,
          initialProfile: _profile,
          isOnboarding: true,
          onSaved: _profileSaved,
        );
      case AuthGateStatus.authenticated:
        return widget.homeBuilder(context, _profile!, _service);
      case AuthGateStatus.passwordRecovery:
        return PasswordRecoveryPage(
          service: _service,
          onCompleted: _completePasswordRecovery,
        );
      case AuthGateStatus.passwordRecoveryInvalid:
        return InvalidPasswordRecoveryPage(
          onRequestNewEmail: _requestNewRecoveryEmail,
        );
      case AuthGateStatus.forgotPassword:
        return ForgotPasswordPage(
          service: _service,
          onBackToLogin: _returnToLogin,
        );
      case AuthGateStatus.error:
        return _AuthErrorPage(
          error: _error ??
              const CustomerAuthException(
                CustomerAuthErrorCode.generic,
              ),
          onRetry: _resolveAuthState,
          onLogout: _logout,
        );
    }
  }
}

class _AuthLoadingPage extends StatelessWidget {
  const _AuthLoadingPage();

  @override
  Widget build(BuildContext context) {
    final strings = CustomerAuthStrings.of(context);
    return AuthPageShell(
      child: AuthCard(
        children: [
          const Center(
            child: SizedBox.square(
              dimension: 42,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            strings.loading,
            key: const Key('auth_loading'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthErrorPage extends StatelessWidget {
  const _AuthErrorPage({
    required this.error,
    required this.onRetry,
    required this.onLogout,
  });

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final strings = CustomerAuthStrings.of(context);
    return AuthPageShell(
      child: AuthCard(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 58,
            color: Color(0xFFB91C1C),
          ),
          const SizedBox(height: 18),
          AuthErrorBanner(message: strings.errorFor(error)),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('auth_retry'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(strings.retry),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onLogout,
            child: Text(strings.logout),
          ),
        ],
      ),
    );
  }
}
