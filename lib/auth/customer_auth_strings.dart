import 'package:flutter/widgets.dart';

import '../services/customer_auth_service.dart';

class CustomerAuthStrings {
  const CustomerAuthStrings(this.languageCode);

  factory CustomerAuthStrings.of(BuildContext context) {
    return CustomerAuthStrings(Localizations.localeOf(context).languageCode);
  }

  final String languageCode;

  String _pick({
    required String it,
    required String de,
    required String fr,
    required String en,
  }) {
    switch (languageCode) {
      case 'it':
        return it;
      case 'fr':
        return fr;
      case 'en':
        return en;
      case 'de':
      default:
        return de;
    }
  }

  String get welcomeTitle => _pick(
        it: 'Benvenuto in CID Digitale',
        de: 'Willkommen bei CID Digitale',
        fr: 'Bienvenue sur CID Digitale',
        en: 'Welcome to CID Digitale',
      );
  String get welcomeSubtitle => _pick(
        it: 'Accedi al tuo spazio Cliente in modo sicuro.',
        de: 'Melde dich sicher in deinem Kundenbereich an.',
        fr: 'Connectez-vous en toute sécurité à votre espace Client.',
        en: 'Securely sign in to your Customer area.',
      );
  String get email => _pick(
        it: 'E-mail',
        de: 'E-Mail',
        fr: 'E-mail',
        en: 'Email',
      );
  String get password => _pick(
        it: 'Password',
        de: 'Passwort',
        fr: 'Mot de passe',
        en: 'Password',
      );
  String get confirmPassword => _pick(
        it: 'Conferma password',
        de: 'Passwort bestätigen',
        fr: 'Confirmer le mot de passe',
        en: 'Confirm password',
      );
  String get showPassword => _pick(
        it: 'Mostra password',
        de: 'Passwort anzeigen',
        fr: 'Afficher le mot de passe',
        en: 'Show password',
      );
  String get hidePassword => _pick(
        it: 'Nascondi password',
        de: 'Passwort ausblenden',
        fr: 'Masquer le mot de passe',
        en: 'Hide password',
      );
  String get signIn => _pick(
        it: 'Accedi',
        de: 'Anmelden',
        fr: 'Se connecter',
        en: 'Sign in',
      );
  String get register => _pick(
        it: 'Registrati',
        de: 'Registrieren',
        fr: 'Créer un compte',
        en: 'Register',
      );
  String get forgotPassword => _pick(
        it: 'Password dimenticata?',
        de: 'Passwort vergessen?',
        fr: 'Mot de passe oublié ?',
        en: 'Forgot password?',
      );
  String get noAccount => _pick(
        it: 'Non hai ancora un account?',
        de: 'Noch kein Konto?',
        fr: 'Vous n’avez pas encore de compte ?',
        en: 'Don’t have an account yet?',
      );
  String get haveAccount => _pick(
        it: 'Hai già un account?',
        de: 'Du hast bereits ein Konto?',
        fr: 'Vous avez déjà un compte ?',
        en: 'Already have an account?',
      );
  String get registrationTitle => _pick(
        it: 'Crea il tuo account Cliente',
        de: 'Erstelle dein Kundenkonto',
        fr: 'Créez votre compte Client',
        en: 'Create your Customer account',
      );
  String get registrationSubtitle => _pick(
        it: 'Inserisci i tuoi dati per iniziare. Il profilo verrà completato nel passaggio successivo.',
        de: 'Gib deine Daten ein. Dein Profil wird im nächsten Schritt vervollständigt.',
        fr: 'Saisissez vos données. Votre profil sera complété à l’étape suivante.',
        en: 'Enter your details. You will complete your profile in the next step.',
      );
  String get firstName => _pick(
        it: 'Nome',
        de: 'Vorname',
        fr: 'Prénom',
        en: 'First name',
      );
  String get lastName => _pick(
        it: 'Cognome',
        de: 'Nachname',
        fr: 'Nom',
        en: 'Last name',
      );
  String get requiredField => _pick(
        it: 'Campo obbligatorio.',
        de: 'Pflichtfeld.',
        fr: 'Champ obligatoire.',
        en: 'Required field.',
      );
  String get invalidEmail => _pick(
        it: 'Inserisci un indirizzo e-mail valido.',
        de: 'Gib eine gültige E-Mail-Adresse ein.',
        fr: 'Saisissez une adresse e-mail valide.',
        en: 'Enter a valid email address.',
      );
  String get passwordTooShort => _pick(
        it: 'La password deve contenere almeno 8 caratteri.',
        de: 'Das Passwort muss mindestens 8 Zeichen enthalten.',
        fr: 'Le mot de passe doit contenir au moins 8 caractères.',
        en: 'The password must be at least 8 characters.',
      );
  String get passwordMismatch => _pick(
        it: 'Le password non coincidono.',
        de: 'Die Passwörter stimmen nicht überein.',
        fr: 'Les mots de passe ne correspondent pas.',
        en: 'Passwords do not match.',
      );
  String get confirmationTitle => _pick(
        it: 'Controlla la tua e-mail',
        de: 'Prüfe deine E-Mails',
        fr: 'Consultez votre e-mail',
        en: 'Check your email',
      );
  String get confirmationBody => _pick(
        it: 'Ti abbiamo inviato il link di conferma. Dopo aver confermato l’indirizzo, torna qui ed effettua l’accesso.',
        de: 'Wir haben dir einen Bestätigungslink gesendet. Bestätige deine Adresse und melde dich danach hier an.',
        fr: 'Nous vous avons envoyé un lien de confirmation. Confirmez votre adresse, puis revenez vous connecter.',
        en: 'We sent you a confirmation link. Confirm your address, then return here to sign in.',
      );
  String get backToLogin => _pick(
        it: 'Torna al login',
        de: 'Zurück zur Anmeldung',
        fr: 'Retour à la connexion',
        en: 'Back to sign in',
      );
  String get resetTitle => _pick(
        it: 'Reimposta la password',
        de: 'Passwort zurücksetzen',
        fr: 'Réinitialiser le mot de passe',
        en: 'Reset your password',
      );
  String get resetSubtitle => _pick(
        it: 'Inserisci la tua e-mail e riceverai le istruzioni per scegliere una nuova password.',
        de: 'Gib deine E-Mail ein. Wir senden dir Anweisungen für ein neues Passwort.',
        fr: 'Saisissez votre e-mail pour recevoir les instructions de réinitialisation.',
        en: 'Enter your email to receive instructions for choosing a new password.',
      );
  String get sendReset => _pick(
        it: 'Invia e-mail di reset',
        de: 'Reset-E-Mail senden',
        fr: 'Envoyer l’e-mail',
        en: 'Send reset email',
      );
  String get resetSentTitle => _pick(
        it: 'E-mail inviata',
        de: 'E-Mail gesendet',
        fr: 'E-mail envoyé',
        en: 'Email sent',
      );
  String get resetSentBody => _pick(
        it: 'Se l’indirizzo è registrato, riceverai a breve le istruzioni per reimpostare la password.',
        de: 'Wenn die Adresse registriert ist, erhältst du in Kürze die Anweisungen.',
        fr: 'Si l’adresse est enregistrée, vous recevrez bientôt les instructions.',
        en: 'If the address is registered, you will receive reset instructions shortly.',
      );
  String get newPasswordTitle => _pick(
        it: 'Crea una nuova password',
        de: 'Neues Passwort erstellen',
        fr: 'Créer un nouveau mot de passe',
        en: 'Create a new password',
      );
  String get newPasswordSubtitle => _pick(
        it: 'Scegli una nuova password sicura per il tuo account.',
        de: 'Wähle ein neues sicheres Passwort für dein Konto.',
        fr: 'Choisissez un nouveau mot de passe sécurisé pour votre compte.',
        en: 'Choose a new secure password for your account.',
      );
  String get newPassword => _pick(
        it: 'Nuova password',
        de: 'Neues Passwort',
        fr: 'Nouveau mot de passe',
        en: 'New password',
      );
  String get confirmNewPassword => _pick(
        it: 'Conferma nuova password',
        de: 'Neues Passwort bestätigen',
        fr: 'Confirmer le nouveau mot de passe',
        en: 'Confirm new password',
      );
  String get saveNewPassword => _pick(
        it: 'Salva nuova password',
        de: 'Neues Passwort speichern',
        fr: 'Enregistrer le nouveau mot de passe',
        en: 'Save new password',
      );
  String get passwordUpdated => _pick(
        it: 'Password aggiornata correttamente. La nuova password è valida sia nel CID Cliente sia nel Tool Officina.',
        de: 'Passwort erfolgreich aktualisiert. Das neue Passwort gilt sowohl für CID Cliente als auch für das Werkstatt-Tool.',
        fr: 'Mot de passe mis à jour avec succès. Le nouveau mot de passe est valable pour CID Cliente et l’outil Atelier.',
        en: 'Password updated successfully. The new password works for both CID Customer and the Workshop Tool.',
      );
  String get recoveryLinkInvalid => _pick(
        it: 'Il link di recupero non è più valido. Richiedi una nuova e-mail.',
        de: 'Der Wiederherstellungslink ist nicht mehr gültig. Fordere eine neue E-Mail an.',
        fr: 'Le lien de récupération n’est plus valide. Demandez un nouvel e-mail.',
        en: 'The recovery link is no longer valid. Request a new email.',
      );
  String get requestNewRecoveryEmail => _pick(
        it: 'Torna a Password dimenticata',
        de: 'Zurück zu Passwort vergessen',
        fr: 'Retour à Mot de passe oublié',
        en: 'Back to Forgot password',
      );
  String get profileSetupTitle => _pick(
        it: 'Completa il tuo profilo Cliente',
        de: 'Vervollständige dein Kundenprofil',
        fr: 'Complétez votre profil Client',
        en: 'Complete your Customer profile',
      );
  String get profileSetupSubtitle => _pick(
        it: 'Questi dati identificano il tuo account Cliente. Il QR personale resta separato e invariato.',
        de: 'Diese Daten gehören zu deinem Kundenkonto. Dein persönlicher QR bleibt getrennt und unverändert.',
        fr: 'Ces données identifient votre compte Client. Votre QR personnel reste séparé et inchangé.',
        en: 'These details identify your Customer account. Your personal QR remains separate and unchanged.',
      );
  String get profileEditTitle => _pick(
        it: 'Profilo e impostazioni',
        de: 'Profil und Einstellungen',
        fr: 'Profil et paramètres',
        en: 'Profile and settings',
      );
  String get title => _pick(
        it: 'Titolo / appellativo',
        de: 'Anrede / Titel',
        fr: 'Titre / civilité',
        en: 'Title / salutation',
      );
  String get titleMr =>
      _pick(it: 'Signor', de: 'Herr', fr: 'Monsieur', en: 'Mr');
  String get titleMrs =>
      _pick(it: 'Signora', de: 'Frau', fr: 'Madame', en: 'Mrs');
  String get titleOther =>
      _pick(it: 'Altro', de: 'Andere', fr: 'Autre', en: 'Other');
  String get street => _pick(it: 'Via', de: 'Strasse', fr: 'Rue', en: 'Street');
  String get postalCode =>
      _pick(it: 'CAP', de: 'PLZ', fr: 'Code postal', en: 'Postal code');
  String get city => _pick(it: 'Città', de: 'Ort', fr: 'Ville', en: 'City');
  String get country =>
      _pick(it: 'Paese', de: 'Land', fr: 'Pays', en: 'Country');
  String get phone =>
      _pick(it: 'Telefono', de: 'Telefon', fr: 'Téléphone', en: 'Phone');
  String get accountEmail => _pick(
        it: 'E-mail dell’account (non modificabile)',
        de: 'Konto-E-Mail (nicht änderbar)',
        fr: 'E-mail du compte (non modifiable)',
        en: 'Account email (read-only)',
      );
  String get saveProfile => _pick(
        it: 'Salva profilo',
        de: 'Profil speichern',
        fr: 'Enregistrer le profil',
        en: 'Save profile',
      );
  String get saving => _pick(
        it: 'Salvataggio…',
        de: 'Wird gespeichert…',
        fr: 'Enregistrement…',
        en: 'Saving…',
      );
  String get profileSaved => _pick(
        it: 'Profilo salvato correttamente.',
        de: 'Profil erfolgreich gespeichert.',
        fr: 'Profil enregistré avec succès.',
        en: 'Profile saved successfully.',
      );
  String get loading => _pick(
        it: 'Caricamento del tuo account…',
        de: 'Dein Konto wird geladen…',
        fr: 'Chargement de votre compte…',
        en: 'Loading your account…',
      );
  String get retry => _pick(
      it: 'Riprova', de: 'Erneut versuchen', fr: 'Réessayer', en: 'Retry');
  String get logout =>
      _pick(it: 'Esci', de: 'Abmelden', fr: 'Déconnexion', en: 'Sign out');
  String get profileTooltip => _pick(
        it: 'Apri profilo e impostazioni',
        de: 'Profil und Einstellungen öffnen',
        fr: 'Ouvrir le profil et les paramètres',
        en: 'Open profile and settings',
      );
  String hello(String firstName) => _pick(
        it: 'Ciao, $firstName',
        de: 'Hallo, $firstName',
        fr: 'Bonjour, $firstName',
        en: 'Hello, $firstName',
      );

  String get privacyPolicy => _pick(
        it: 'Privacy Policy',
        de: 'Datenschutzerklärung',
        fr: 'Politique de confidentialité',
        en: 'Privacy Policy',
      );
  String get termsOfUse => _pick(
        it: 'Termini d’uso',
        de: 'Nutzungsbedingungen',
        fr: 'Conditions d’utilisation',
        en: 'Terms of Use',
      );
  String get privacyAcceptancePrefix => _pick(
        it: 'Ho letto e accetto la',
        de: 'Ich habe die',
        fr: 'J’ai lu et j’accepte la',
        en: 'I have read and accept the',
      );
  String get privacyAcceptanceSuffix => _pick(
        it: '',
        de: 'gelesen und akzeptiere sie.',
        fr: '',
        en: '',
      );
  String get termsAcceptancePrefix => _pick(
        it: 'Ho letto e accetto i',
        de: 'Ich habe die',
        fr: 'J’ai lu et j’accepte les',
        en: 'I have read and accept the',
      );
  String get termsAcceptanceSuffix => _pick(
        it: '',
        de: 'gelesen und akzeptiere sie.',
        fr: '',
        en: '',
      );
  String get legalAcceptanceRequired => _pick(
        it: 'Devi accettare per continuare.',
        de: 'Du musst zustimmen, um fortzufahren.',
        fr: 'Vous devez accepter pour continuer.',
        en: 'You must accept to continue.',
      );
  String get legalDocumentsTitle => _pick(
        it: 'Privacy e condizioni',
        de: 'Datenschutz und Bedingungen',
        fr: 'Confidentialité et conditions',
        en: 'Privacy and terms',
      );
  String get legalDocumentsSubtitle => _pick(
        it: 'Consulta in qualsiasi momento i documenti applicabili al tuo account Cliente.',
        de: 'Lies jederzeit die für dein Kundenkonto geltenden Dokumente.',
        fr: 'Consultez à tout moment les documents applicables à votre compte Client.',
        en: 'Review the documents applying to your Customer account at any time.',
      );

  String errorFor(Object error) {
    final code = error is CustomerAuthException
        ? error.code
        : CustomerAuthErrorCode.generic;
    switch (code) {
      case CustomerAuthErrorCode.invalidCredentials:
        return _pick(
          it: 'E-mail o password non corretti.',
          de: 'E-Mail oder Passwort ist nicht korrekt.',
          fr: 'E-mail ou mot de passe incorrect.',
          en: 'Incorrect email or password.',
        );
      case CustomerAuthErrorCode.emailNotConfirmed:
        return _pick(
          it: 'Conferma prima il tuo indirizzo e-mail.',
          de: 'Bestätige zuerst deine E-Mail-Adresse.',
          fr: 'Confirmez d’abord votre adresse e-mail.',
          en: 'Confirm your email address first.',
        );
      case CustomerAuthErrorCode.emailAlreadyRegistered:
        return _pick(
          it: 'Esiste già un account con questa e-mail. Accedi con la password esistente per attivare anche il profilo Cliente.',
          de: 'Für diese E-Mail existiert bereits ein Konto. Melde dich mit dem bestehenden Passwort an, um auch das Kundenprofil zu aktivieren.',
          fr: 'Un compte existe déjà avec cet e-mail. Connectez-vous avec le mot de passe existant pour activer aussi le profil Client.',
          en: 'An account already exists for this email. Sign in with the existing password to activate the Customer profile too.',
        );
      case CustomerAuthErrorCode.weakPassword:
        return passwordTooShort;
      case CustomerAuthErrorCode.rateLimited:
        return _pick(
          it: 'Troppi tentativi. Attendi qualche minuto e riprova.',
          de: 'Zu viele Versuche. Warte einige Minuten und versuche es erneut.',
          fr: 'Trop de tentatives. Patientez quelques minutes et réessayez.',
          en: 'Too many attempts. Wait a few minutes and try again.',
        );
      case CustomerAuthErrorCode.notCustomer:
        return _pick(
          it: 'Questo account non è un account Cliente.',
          de: 'Dieses Konto ist kein Kundenkonto.',
          fr: 'Ce compte n’est pas un compte Client.',
          en: 'This is not a Customer account.',
        );
      case CustomerAuthErrorCode.unauthenticated:
        return _pick(
          it: 'La sessione è scaduta. Accedi nuovamente.',
          de: 'Die Sitzung ist abgelaufen. Melde dich erneut an.',
          fr: 'La session a expiré. Reconnectez-vous.',
          en: 'Your session expired. Sign in again.',
        );
      case CustomerAuthErrorCode.profileUnavailable:
        return _pick(
          it: 'Impossibile caricare o salvare il profilo. Controlla la connessione e riprova.',
          de: 'Das Profil kann nicht geladen oder gespeichert werden. Prüfe die Verbindung.',
          fr: 'Impossible de charger ou d’enregistrer le profil. Vérifiez la connexion.',
          en: 'Unable to load or save the profile. Check your connection and retry.',
        );
      case CustomerAuthErrorCode.generic:
        return _pick(
          it: 'Si è verificato un errore. Riprova.',
          de: 'Ein Fehler ist aufgetreten. Versuche es erneut.',
          fr: 'Une erreur s’est produite. Réessayez.',
          en: 'Something went wrong. Please try again.',
        );
    }
  }

  String get signInAndCompleteCustomerProfile => _pick(
        it: 'Accedi e completa il profilo Cliente',
        de: 'Anmelden und Kundenprofil vervollständigen',
        fr: 'Se connecter et compléter le profil Client',
        en: 'Sign in and complete Customer profile',
      );
}
