class CustomerAuthValidators {
  const CustomerAuthValidators._();

  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static bool isValidEmail(String value) =>
      _emailPattern.hasMatch(value.trim());

  static String? requiredValue(String? value, String message) {
    return value == null || value.trim().isEmpty ? message : null;
  }

  static String? email(
    String? value, {
    required String requiredMessage,
    required String invalidMessage,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return requiredMessage;
    if (!isValidEmail(text)) return invalidMessage;
    return null;
  }

  static String? password(
    String? value, {
    required String requiredMessage,
    required String tooShortMessage,
  }) {
    final text = value ?? '';
    if (text.isEmpty) return requiredMessage;
    if (text.length < 8) return tooShortMessage;
    return null;
  }

  static String? passwordConfirmation(
    String? value, {
    required String password,
    required String requiredMessage,
    required String mismatchMessage,
  }) {
    if (value == null || value.isEmpty) return requiredMessage;
    if (value != password) return mismatchMessage;
    return null;
  }
}
