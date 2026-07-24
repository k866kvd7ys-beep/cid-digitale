import 'package:cid_digitale/auth/customer_auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('customer registration validation', () {
    test('requires every registration value and a valid email', () {
      expect(
        CustomerAuthValidators.requiredValue('', 'required'),
        'required',
      );
      expect(
        CustomerAuthValidators.email(
          'not-an-email',
          requiredMessage: 'required',
          invalidMessage: 'invalid',
        ),
        'invalid',
      );
      expect(
        CustomerAuthValidators.email(
          'cliente@example.com',
          requiredMessage: 'required',
          invalidMessage: 'invalid',
        ),
        isNull,
      );
    });

    test('requires at least eight password characters', () {
      expect(
        CustomerAuthValidators.password(
          '1234567',
          requiredMessage: 'required',
          tooShortMessage: 'short',
        ),
        'short',
      );
      expect(
        CustomerAuthValidators.password(
          '12345678',
          requiredMessage: 'required',
          tooShortMessage: 'short',
        ),
        isNull,
      );
    });

    test('rejects a password confirmation that does not match', () {
      expect(
        CustomerAuthValidators.passwordConfirmation(
          'different',
          password: 'password123',
          requiredMessage: 'required',
          mismatchMessage: 'mismatch',
        ),
        'mismatch',
      );
      expect(
        CustomerAuthValidators.passwordConfirmation(
          'password123',
          password: 'password123',
          requiredMessage: 'required',
          mismatchMessage: 'mismatch',
        ),
        isNull,
      );
    });
  });
}
