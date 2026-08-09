import 'package:flutter/material.dart';

import '../../auth/customer_auth_strings.dart';
import '../../models/customer_legal_acceptance.dart';

enum LegalDocumentType { privacyPolicy, termsOfUse }

class _LegalSection {
  const _LegalSection(this.title, this.body);

  final String title;
  final String body;
}

class _LegalDocumentCopy {
  const _LegalDocumentCopy({
    required this.title,
    required this.eyebrow,
    required this.summary,
    required this.draftTitle,
    required this.draftBody,
    required this.lastUpdated,
    required this.sections,
  });

  final String title;
  final String eyebrow;
  final String summary;
  final String draftTitle;
  final String draftBody;
  final String lastUpdated;
  final List<_LegalSection> sections;
}

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({
    super.key,
    required this.documentType,
  });

  final LegalDocumentType documentType;

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final copy = _copyFor(languageCode, documentType);

    return Scaffold(
      key: Key(
        documentType == LegalDocumentType.privacyPolicy
            ? 'privacy_policy_page'
            : 'terms_of_use_page',
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(copy.title),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 720 ? 32.0 : 16.0;
            return SingleChildScrollView(
              key: const Key('legal_document_scroll'),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                20,
                horizontalPadding,
                40,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LegalHeader(copy: copy, documentType: documentType),
                      const SizedBox(height: 16),
                      _DraftNotice(copy: copy),
                      const SizedBox(height: 16),
                      for (var index = 0;
                          index < copy.sections.length;
                          index++) ...[
                        _SectionCard(
                          key: Key('legal_section_$index'),
                          section: copy.sections[index],
                        ),
                        if (index < copy.sections.length - 1)
                          const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class LegalDocumentsPanel extends StatelessWidget {
  const LegalDocumentsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = CustomerAuthStrings.of(context);
    return Container(
      key: const Key('profile_legal_documents'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.policy_outlined,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  strings.legalDocumentsTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            strings.legalDocumentsSubtitle,
            style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            key: const Key('profile_privacy_policy_link'),
            onPressed: () => _openDocument(
              context,
              LegalDocumentType.privacyPolicy,
            ),
            icon: const Icon(Icons.privacy_tip_outlined),
            label: Text(strings.privacyPolicy),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              alignment: Alignment.centerLeft,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('profile_terms_of_use_link'),
            onPressed: () => _openDocument(
              context,
              LegalDocumentType.termsOfUse,
            ),
            icon: const Icon(Icons.description_outlined),
            label: Text(strings.termsOfUse),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              alignment: Alignment.centerLeft,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> openLegalDocument(
  BuildContext context,
  LegalDocumentType documentType,
) {
  return _openDocument(context, documentType);
}

Future<void> _openDocument(
  BuildContext context,
  LegalDocumentType documentType,
) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => LegalDocumentPage(documentType: documentType),
    ),
  );
}

class _LegalHeader extends StatelessWidget {
  const _LegalHeader({
    required this.copy,
    required this.documentType,
  });

  final _LegalDocumentCopy copy;
  final LegalDocumentType documentType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F3D68), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            documentType == LegalDocumentType.privacyPolicy
                ? Icons.privacy_tip_outlined
                : Icons.gavel_outlined,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(height: 16),
          Text(
            copy.eyebrow.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFBFDBFE),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            copy.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            copy.summary,
            style: const TextStyle(
              color: Color(0xFFEFF6FF),
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            copy.lastUpdated,
            style: const TextStyle(
              color: Color(0xFFDBEAFE),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftNotice extends StatelessWidget {
  const _DraftNotice({required this.copy});

  final _LegalDocumentCopy copy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Container(
        key: const Key('legal_draft_notice'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.fact_check_outlined,
              color: Color(0xFFB45309),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.draftTitle,
                    style: const TextStyle(
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    copy.draftBody,
                    style: const TextStyle(
                      color: Color(0xFF78350F),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({super.key, required this.section});

  final _LegalSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            section.body,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 15.5,
              height: 1.58,
            ),
          ),
        ],
      ),
    );
  }
}

_LegalDocumentCopy _copyFor(
  String languageCode,
  LegalDocumentType documentType,
) {
  if (documentType == LegalDocumentType.privacyPolicy) {
    return switch (languageCode) {
      'de' => _privacyDe,
      'fr' => _privacyFr,
      'en' => _privacyEn,
      _ => _privacyIt,
    };
  }
  return switch (languageCode) {
    'de' => _termsDe,
    'fr' => _termsFr,
    'en' => _termsEn,
    _ => _termsIt,
  };
}

const _privacyIt = _LegalDocumentCopy(
  title: 'Privacy Policy',
  eyebrow: 'CID Digitale · Area Cliente',
  summary:
      'Questa informativa descrive come vengono trattati i dati personali quando utilizzi il CID Cliente e i servizi collegati.',
  draftTitle: 'Bozza da completare prima della pubblicazione',
  draftBody:
      'Il contenuto riflette le funzioni e i fornitori verificati nel progetto. Restano da confermare legalmente: identità e indirizzo completi del titolare, regioni e garanzie dei trasferimenti, tempi di conservazione e mappatura definitiva delle basi giuridiche.',
  lastUpdated:
      'Ultimo aggiornamento: 8 agosto 2026 · Versione $privacyPolicyVersion',
  sections: [
    _LegalSection(
      '1. Titolare del trattamento e contatti',
      'Titolare: CID Digitale. Denominazione legale completa, indirizzo postale e numero IDE/registro: DA CONFERMARE LEGALMENTE prima della pubblicazione.\n\nPer domande o per esercitare i tuoi diritti: support@ciddigital.ch.',
    ),
    _LegalSection(
      '2. Dati trattati',
      'A seconda delle funzioni utilizzate, il servizio può trattare:\n\n• dati di account e profilo Cliente, come nome, contatti, indirizzo e credenziali gestite dal sistema di autenticazione;\n• dati di veicoli e assicurazioni, come targa, caratteristiche del veicolo, compagnia e dati di polizza;\n• dati relativi a sinistri e pratiche, inclusi luogo, data, dinamica, soggetti coinvolti, firme e responsabilità indicate dagli utenti;\n• foto, immagini, documenti, allegati, dati estratti tramite OCR ed eventuali registrazioni audio;\n• messaggi, richieste di assistenza, richieste di appuntamento e comunicazioni;\n• dati tecnici necessari a sessione, sicurezza, funzionamento e diagnosi degli errori.',
    ),
    _LegalSection(
      '3. Finalità del trattamento',
      'I dati sono trattati per creare e gestire l’account Cliente; compilare, salvare e condividere pratiche CID; gestire veicoli, documenti e storico; elaborare immagini o documenti richiesti dall’utente; inoltrare richieste a officine e assicurazioni coinvolte; inviare comunicazioni operative; fornire assistenza; proteggere account e piattaforma; adempiere a obblighi applicabili e tutelare diritti in caso di contestazioni.',
    ),
    _LegalSection(
      '4. Basi giuridiche',
      'A seconda dell’attività e della legge applicabile, il trattamento può fondarsi sull’esecuzione del servizio richiesto o su misure precontrattuali, sul consenso quando necessario, su obblighi legali e su interessi legittimi o privati prevalenti quali sicurezza, prevenzione degli abusi e difesa di diritti.\n\nDA VERIFICARE LEGALMENTE: la mappatura puntuale tra ogni finalità e la relativa base giuridica, inclusa l’eventuale applicazione del GDPR oltre alla legge svizzera sulla protezione dei dati.',
    ),
    _LegalSection(
      '5. Officine, assicurazioni e altri destinatari',
      'I dati di una pratica o richiesta possono essere condivisi con le officine e le assicurazioni effettivamente coinvolte, quando ciò è richiesto dall’utente o necessario al flusso scelto. Ciascun destinatario può trattare i dati sotto la propria responsabilità secondo il ruolo applicabile. I dati possono inoltre essere accessibili a fornitori tecnici e consulenti autorizzati nella misura necessaria al servizio o a obblighi di legge.',
    ),
    _LegalSection(
      '6. Fornitori tecnici verificati nel progetto',
      'Il codice del progetto utilizza:\n\n• Supabase per autenticazione, database, storage ed Edge Functions;\n• Vercel per hosting e distribuzione dell’applicazione web;\n• Resend per l’invio di e-mail operative;\n• servizi Google per ricerca/visualizzazione di luoghi e officine e, quando configurato, OCR Cloud Vision; l’app usa inoltre ML Kit per riconoscimento del testo sul dispositivo;\n• OpenStreetMap Nominatim per la geocodifica inversa;\n• Tesseract.js, distribuito tramite jsDelivr, per funzioni OCR sul web.\n\nL’effettivo impiego può dipendere dalla piattaforma e dalla funzione utilizzata. Contratti, ruoli privacy, sottofornitori e configurazioni di produzione devono essere verificati dal titolare.',
    ),
    _LegalSection(
      '7. Ubicazione e trasferimenti dei dati',
      'Il repository conferma i servizi usati, ma non consente di verificare le regioni selezionate negli account di produzione né tutti i luoghi dei sottofornitori. I dati possono quindi essere trattati in Svizzera, nello SEE o in altri Paesi in base alla configurazione dei fornitori.\n\nDA CONFERMARE PRIMA DELLA PUBBLICAZIONE: regioni effettive, Paesi destinatari e garanzie applicabili ai trasferimenti internazionali.',
    ),
    _LegalSection(
      '8. Tempi di conservazione',
      'I dati sono conservati solo per il tempo necessario alle finalità descritte e agli obblighi legali, contrattuali o di difesa applicabili, quindi cancellati o anonimizzati quando possibile.\n\nDA DEFINIRE E CONFERMARE: periodi specifici per account e profili, veicoli, pratiche e sinistri, foto/audio/documenti, messaggi e richieste, e-mail, log tecnici, backup e dati dopo la chiusura dell’account.',
    ),
    _LegalSection(
      '9. Sicurezza',
      'Il progetto prevede autenticazione, controlli di autorizzazione, regole di accesso ai dati e, dove implementato, accessi protetti o temporanei ai file. Sono adottate misure tecniche e organizzative proporzionate al rischio; nessun sistema può tuttavia garantire sicurezza assoluta. Le misure organizzative, le procedure di risposta agli incidenti e le configurazioni di produzione devono essere confermate dal titolare.',
    ),
    _LegalSection(
      '10. Diritti dell’interessato',
      'Nei limiti della legge applicabile puoi chiedere informazioni e accesso ai dati, rettifica di dati inesatti, cancellazione o limitazione del trattamento, opposizione, consegna o portabilità dei dati quando prevista e revoca del consenso per il futuro. Alcuni diritti possono essere limitati da obblighi di conservazione o da altri motivi legittimi.',
    ),
    _LegalSection(
      '11. Come presentare una richiesta',
      'Invia la richiesta a support@ciddigital.ch indicando il diritto che vuoi esercitare e le informazioni necessarie a identificare l’account. Per proteggere i dati potrà essere richiesta una verifica ragionevole dell’identità. La richiesta sarà gestita entro i termini della legge applicabile. Puoi inoltre rivolgerti all’autorità di protezione dei dati competente.',
    ),
    _LegalSection(
      '12. Modifiche alla Privacy Policy',
      'Questa informativa può essere aggiornata quando cambiano il servizio, i fornitori o gli obblighi applicabili. La versione e la data di aggiornamento permettono di identificare il testo vigente. Le modifiche rilevanti saranno comunicate con modalità adeguate.',
    ),
  ],
);

const _privacyDe = _LegalDocumentCopy(
  title: 'Datenschutzerklärung',
  eyebrow: 'CID Digitale · Kundenbereich',
  summary:
      'Diese Erklärung beschreibt, wie personenbezogene Daten bei der Nutzung des CID-Kundenbereichs und der verbundenen Dienste bearbeitet werden.',
  draftTitle: 'Entwurf – vor der Veröffentlichung zu vervollständigen',
  draftBody:
      'Der Inhalt entspricht den im Projekt geprüften Funktionen und Anbietern. Rechtlich zu bestätigen sind insbesondere: vollständige Identität und Anschrift des Verantwortlichen, Regionen und Garantien für Datenübermittlungen, Aufbewahrungsfristen und die endgültige Zuordnung der Rechtsgrundlagen.',
  lastUpdated:
      'Letzte Aktualisierung: 8. August 2026 · Version $privacyPolicyVersion',
  sections: [
    _LegalSection(
      '1. Verantwortlicher und Kontakt',
      'Verantwortlicher: CID Digitale. Vollständige juristische Bezeichnung, Postanschrift und UID-/Registernummer: VOR DER VERÖFFENTLICHUNG RECHTLICH ZU BESTÄTIGEN.\n\nFür Fragen oder zur Ausübung deiner Rechte: support@ciddigital.ch.',
    ),
    _LegalSection(
      '2. Bearbeitete Daten',
      'Je nach genutzter Funktion kann der Dienst folgende Daten bearbeiten:\n\n• Konto- und Kundenprofildaten wie Name, Kontakt- und Adressdaten sowie vom Authentifizierungssystem verwaltete Zugangsdaten;\n• Fahrzeug- und Versicherungsdaten wie Kennzeichen, Fahrzeugmerkmale, Versicherer und Policenangaben;\n• Angaben zu Unfällen und Fällen, darunter Ort, Datum, Hergang, Beteiligte, Unterschriften und von Nutzenden gemachte Haftungsangaben;\n• Fotos, Bilder, Dokumente, Anhänge, per OCR erkannte Daten und allfällige Audioaufnahmen;\n• Nachrichten, Support- und Terminanfragen sowie Kommunikation;\n• technische Daten, die für Sitzung, Sicherheit, Betrieb und Fehlerdiagnose notwendig sind.',
    ),
    _LegalSection(
      '3. Bearbeitungszwecke',
      'Die Daten werden bearbeitet, um das Kundenkonto zu erstellen und zu verwalten; CID-Fälle auszufüllen, zu speichern und zu teilen; Fahrzeuge, Dokumente und Verlauf zu verwalten; vom Nutzer angeforderte Bild- oder Dokumentverarbeitung auszuführen; Anfragen an beteiligte Werkstätten und Versicherungen weiterzuleiten; betriebliche Mitteilungen und Support bereitzustellen; Konten und Plattform zu schützen; anwendbare Pflichten zu erfüllen und Rechte bei Streitigkeiten zu wahren.',
    ),
    _LegalSection(
      '4. Rechtsgrundlagen',
      'Je nach Vorgang und anwendbarem Recht kann die Bearbeitung auf der Erfüllung des angeforderten Dienstes oder vorvertraglichen Massnahmen, einer erforderlichen Einwilligung, gesetzlichen Pflichten sowie überwiegenden berechtigten oder privaten Interessen wie Sicherheit, Missbrauchsprävention und Rechtsverteidigung beruhen.\n\nRECHTLICH ZU PRÜFEN: die genaue Zuordnung jeder Bearbeitung zu ihrer Rechtsgrundlage und eine mögliche Anwendbarkeit der DSGVO zusätzlich zum schweizerischen Datenschutzrecht.',
    ),
    _LegalSection(
      '5. Werkstätten, Versicherungen und weitere Empfänger',
      'Daten eines Falls oder einer Anfrage können an die tatsächlich beteiligten Werkstätten und Versicherungen weitergegeben werden, wenn der Nutzer dies verlangt oder der gewählte Ablauf es erfordert. Jeder Empfänger kann die Daten entsprechend seiner anwendbaren Rolle eigenverantwortlich bearbeiten. Technische Anbieter und autorisierte Berater können im für den Dienst oder gesetzliche Pflichten nötigen Umfang Zugriff erhalten.',
    ),
    _LegalSection(
      '6. Im Projekt geprüfte technische Anbieter',
      'Der Projektcode verwendet:\n\n• Supabase für Authentifizierung, Datenbank, Speicher und Edge Functions;\n• Vercel für Hosting und Bereitstellung der Webanwendung;\n• Resend für betriebliche E-Mails;\n• Google-Dienste für Orts-/Werkstattsuche und Karten sowie, falls konfiguriert, Cloud-Vision-OCR; zusätzlich wird ML Kit für Texterkennung auf dem Gerät eingesetzt;\n• OpenStreetMap Nominatim für Rückwärtsgeokodierung;\n• Tesseract.js, über jsDelivr bereitgestellt, für OCR-Funktionen im Web.\n\nDie tatsächliche Nutzung hängt von Plattform und Funktion ab. Verträge, Datenschutzrollen, Unterauftragsbearbeiter und Produktionskonfigurationen sind vom Verantwortlichen zu prüfen.',
    ),
    _LegalSection(
      '7. Bearbeitungsorte und Datenübermittlungen',
      'Das Repository bestätigt die eingesetzten Dienste, nicht jedoch die in Produktionskonten gewählten Regionen oder alle Standorte von Unterauftragsbearbeitern. Je nach Anbieterkonfiguration können Daten in der Schweiz, im EWR oder in anderen Ländern bearbeitet werden.\n\nVOR DER VERÖFFENTLICHUNG ZU BESTÄTIGEN: tatsächliche Regionen, Empfängerländer und Garantien für internationale Datenübermittlungen.',
    ),
    _LegalSection(
      '8. Aufbewahrungsdauer',
      'Daten werden nur so lange aufbewahrt, wie es für die beschriebenen Zwecke sowie gesetzliche, vertragliche oder beweisrechtliche Pflichten notwendig ist, und danach soweit möglich gelöscht oder anonymisiert.\n\nZU DEFINIEREN UND ZU BESTÄTIGEN: konkrete Fristen für Konten/Profile, Fahrzeuge, Fälle/Unfälle, Fotos/Audio/Dokumente, Nachrichten/Anfragen, E-Mails, technische Protokolle, Sicherungskopien und Daten nach Kontoschliessung.',
    ),
    _LegalSection(
      '9. Sicherheit',
      'Das Projekt sieht Authentifizierung, Berechtigungskontrollen, Datenzugriffsregeln und – wo umgesetzt – geschützte oder zeitlich begrenzte Dateizugriffe vor. Dem Risiko angemessene technische und organisatorische Massnahmen werden eingesetzt; absolute Sicherheit kann kein System garantieren. Organisatorische Massnahmen, Vorfallprozesse und Produktionskonfigurationen sind vom Verantwortlichen zu bestätigen.',
    ),
    _LegalSection(
      '10. Rechte betroffener Personen',
      'Im Rahmen des anwendbaren Rechts kannst du Auskunft und Zugang, Berichtigung unrichtiger Daten, Löschung oder Einschränkung, Widerspruch, Herausgabe oder Übertragbarkeit (soweit vorgesehen) und den Widerruf einer Einwilligung für die Zukunft verlangen. Rechte können durch Aufbewahrungspflichten oder andere rechtmässige Gründe eingeschränkt sein.',
    ),
    _LegalSection(
      '11. So stellst du eine Anfrage',
      'Sende deine Anfrage an support@ciddigital.ch und nenne das gewünschte Recht sowie die zur Identifikation des Kontos nötigen Angaben. Zum Schutz der Daten kann eine angemessene Identitätsprüfung verlangt werden. Die Bearbeitung erfolgt innerhalb der Fristen des anwendbaren Rechts. Du kannst dich zudem an die zuständige Datenschutzbehörde wenden.',
    ),
    _LegalSection(
      '12. Änderungen dieser Datenschutzerklärung',
      'Diese Erklärung kann angepasst werden, wenn sich Dienst, Anbieter oder Pflichten ändern. Version und Aktualisierungsdatum kennzeichnen den geltenden Text. Wesentliche Änderungen werden in geeigneter Weise mitgeteilt.',
    ),
  ],
);

const _privacyFr = _LegalDocumentCopy(
  title: 'Politique de confidentialité',
  eyebrow: 'CID Digitale · Espace Client',
  summary:
      'La présente politique décrit le traitement des données personnelles lors de l’utilisation de l’espace Client CID et des services associés.',
  draftTitle: 'Projet à compléter avant publication',
  draftBody:
      'Le contenu reflète les fonctions et fournisseurs vérifiés dans le projet. Restent à confirmer juridiquement : l’identité et l’adresse complètes du responsable, les régions et garanties de transfert, les durées de conservation et la cartographie définitive des bases juridiques.',
  lastUpdated:
      'Dernière mise à jour : 8 août 2026 · Version $privacyPolicyVersion',
  sections: [
    _LegalSection(
      '1. Responsable du traitement et contact',
      'Responsable : CID Digitale. Dénomination juridique complète, adresse postale et numéro IDE/registre : À CONFIRMER JURIDIQUEMENT avant publication.\n\nPour toute question ou pour exercer vos droits : support@ciddigital.ch.',
    ),
    _LegalSection(
      '2. Données traitées',
      'Selon les fonctions utilisées, le service peut traiter :\n\n• les données de compte et de profil Client, telles que nom, coordonnées, adresse et identifiants gérés par le système d’authentification ;\n• les données relatives aux véhicules et assurances, telles que plaque, caractéristiques, assureur et police ;\n• les données de sinistres et dossiers, notamment lieu, date, circonstances, personnes impliquées, signatures et responsabilités indiquées par les utilisateurs ;\n• les photos, images, documents, pièces jointes, données extraites par OCR et éventuels enregistrements audio ;\n• les messages, demandes d’assistance, rendez-vous et communications ;\n• les données techniques nécessaires à la session, à la sécurité, au fonctionnement et au diagnostic.',
    ),
    _LegalSection(
      '3. Finalités du traitement',
      'Les données servent à créer et gérer le compte Client ; remplir, enregistrer et partager les dossiers CID ; gérer véhicules, documents et historique ; traiter les images ou documents demandés ; transmettre les demandes aux ateliers et assurances concernés ; envoyer les communications opérationnelles ; fournir l’assistance ; protéger les comptes et la plateforme ; respecter les obligations applicables et défendre des droits en cas de litige.',
    ),
    _LegalSection(
      '4. Bases juridiques',
      'Selon l’activité et le droit applicable, le traitement peut reposer sur l’exécution du service demandé ou des mesures précontractuelles, le consentement lorsqu’il est requis, des obligations légales et des intérêts légitimes ou privés prépondérants tels que la sécurité, la prévention des abus et la défense de droits.\n\nÀ VÉRIFIER JURIDIQUEMENT : l’association précise de chaque finalité à sa base juridique et l’éventuelle application du RGPD en plus du droit suisse de la protection des données.',
    ),
    _LegalSection(
      '5. Ateliers, assurances et autres destinataires',
      'Les données d’un dossier ou d’une demande peuvent être communiquées aux ateliers et assurances effectivement concernés lorsque l’utilisateur le demande ou que le parcours choisi l’exige. Chaque destinataire peut traiter les données sous sa propre responsabilité selon son rôle. Les fournisseurs techniques et conseillers autorisés peuvent y accéder dans la mesure nécessaire au service ou aux obligations légales.',
    ),
    _LegalSection(
      '6. Fournisseurs techniques vérifiés dans le projet',
      'Le code du projet utilise :\n\n• Supabase pour l’authentification, la base de données, le stockage et les Edge Functions ;\n• Vercel pour l’hébergement et la distribution de l’application web ;\n• Resend pour les e-mails opérationnels ;\n• des services Google pour les lieux, ateliers et cartes et, s’il est configuré, l’OCR Cloud Vision ; ML Kit est aussi utilisé pour la reconnaissance de texte sur l’appareil ;\n• OpenStreetMap Nominatim pour le géocodage inverse ;\n• Tesseract.js, distribué via jsDelivr, pour l’OCR sur le web.\n\nL’utilisation effective dépend de la plateforme et de la fonction. Les contrats, rôles, sous-traitants ultérieurs et configurations de production doivent être vérifiés par le responsable.',
    ),
    _LegalSection(
      '7. Lieu du traitement et transferts',
      'Le dépôt confirme les services utilisés, mais pas les régions choisies dans les comptes de production ni tous les lieux des sous-traitants ultérieurs. Selon la configuration, les données peuvent être traitées en Suisse, dans l’EEE ou dans d’autres pays.\n\nÀ CONFIRMER AVANT PUBLICATION : régions effectives, pays destinataires et garanties applicables aux transferts internationaux.',
    ),
    _LegalSection(
      '8. Durées de conservation',
      'Les données sont conservées uniquement pendant la durée nécessaire aux finalités décrites et aux obligations légales, contractuelles ou de défense, puis supprimées ou anonymisées lorsque cela est possible.\n\nÀ DÉFINIR ET CONFIRMER : durées propres aux comptes/profils, véhicules, dossiers/sinistres, photos/audio/documents, messages/demandes, e-mails, journaux techniques, sauvegardes et données après fermeture du compte.',
    ),
    _LegalSection(
      '9. Sécurité',
      'Le projet prévoit une authentification, des contrôles d’autorisation, des règles d’accès aux données et, lorsqu’ils sont mis en œuvre, des accès protégés ou temporaires aux fichiers. Des mesures techniques et organisationnelles proportionnées au risque sont appliquées ; aucun système ne garantit toutefois une sécurité absolue. Les mesures organisationnelles, procédures d’incident et configurations de production doivent être confirmées par le responsable.',
    ),
    _LegalSection(
      '10. Droits de la personne concernée',
      'Dans les limites du droit applicable, vous pouvez demander information et accès, rectification, effacement ou limitation, opposition, remise ou portabilité lorsque prévue, ainsi que retirer un consentement pour l’avenir. Certains droits peuvent être limités par des obligations de conservation ou d’autres motifs légitimes.',
    ),
    _LegalSection(
      '11. Présenter une demande',
      'Écrivez à support@ciddigital.ch en précisant le droit exercé et les informations nécessaires pour identifier le compte. Une vérification raisonnable de l’identité peut être demandée afin de protéger les données. La demande sera traitée dans les délais du droit applicable. Vous pouvez aussi saisir l’autorité de protection des données compétente.',
    ),
    _LegalSection(
      '12. Modifications de la politique',
      'Cette politique peut évoluer avec le service, les fournisseurs ou les obligations applicables. La version et la date identifient le texte en vigueur. Les modifications importantes seront communiquées de manière appropriée.',
    ),
  ],
);

const _privacyEn = _LegalDocumentCopy(
  title: 'Privacy Policy',
  eyebrow: 'CID Digitale · Customer Area',
  summary:
      'This policy explains how personal data is processed when you use the CID Customer area and connected services.',
  draftTitle: 'Draft to be completed before publication',
  draftBody:
      'The content reflects functions and providers verified in the project. The following still require legal confirmation: the controller’s full identity and address, processing regions and transfer safeguards, retention periods, and the final mapping of legal bases.',
  lastUpdated: 'Last updated: 8 August 2026 · Version $privacyPolicyVersion',
  sections: [
    _LegalSection(
      '1. Controller and contact details',
      'Controller: CID Digitale. Full legal name, postal address, and UID/registration number: TO BE LEGALLY CONFIRMED before publication.\n\nFor questions or to exercise your rights: support@ciddigital.ch.',
    ),
    _LegalSection(
      '2. Data we process',
      'Depending on the features you use, the service may process:\n\n• Customer account and profile data, such as name, contact details, address, and credentials managed by the authentication system;\n• vehicle and insurance data, such as licence plate, vehicle details, insurer, and policy information;\n• accident and case data, including location, date, circumstances, people involved, signatures, and responsibility indicated by users;\n• photos, images, documents, attachments, OCR-extracted data, and any audio recordings;\n• messages, support requests, appointment requests, and communications;\n• technical data required for sessions, security, operation, and error diagnosis.',
    ),
    _LegalSection(
      '3. Purposes of processing',
      'Data is processed to create and manage the Customer account; complete, store, and share CID cases; manage vehicles, documents, and history; process images or documents requested by the user; send requests to involved workshops and insurers; deliver operational communications; provide support; protect accounts and the platform; meet applicable obligations; and protect rights in disputes.',
    ),
    _LegalSection(
      '4. Legal bases',
      'Depending on the activity and applicable law, processing may rely on performance of the requested service or pre-contractual steps, consent where required, legal obligations, and overriding legitimate or private interests such as security, abuse prevention, and legal defence.\n\nLEGAL REVIEW REQUIRED: the exact mapping of each purpose to its legal basis and whether the GDPR applies in addition to Swiss data protection law.',
    ),
    _LegalSection(
      '5. Workshops, insurers, and other recipients',
      'Case or request data may be shared with the workshops and insurers actually involved where requested by the user or required by the selected workflow. Each recipient may process data under its own responsibility according to its applicable role. Technical providers and authorised advisers may access data to the extent necessary for the service or legal obligations.',
    ),
    _LegalSection(
      '6. Technical providers verified in the project',
      'The project code uses:\n\n• Supabase for authentication, database, storage, and Edge Functions;\n• Vercel for web application hosting and delivery;\n• Resend for operational email;\n• Google services for places, workshop search, and maps and, where configured, Cloud Vision OCR; ML Kit is also used for on-device text recognition;\n• OpenStreetMap Nominatim for reverse geocoding;\n• Tesseract.js, delivered through jsDelivr, for web OCR features.\n\nActual use depends on the platform and selected feature. The controller must verify contracts, privacy roles, subprocessors, and production configurations.',
    ),
    _LegalSection(
      '7. Processing locations and transfers',
      'The repository confirms the services used, but not the regions selected in production accounts or every subprocessor location. Depending on provider configuration, data may be processed in Switzerland, the EEA, or other countries.\n\nTO BE CONFIRMED BEFORE PUBLICATION: actual regions, destination countries, and safeguards applying to international transfers.',
    ),
    _LegalSection(
      '8. Retention periods',
      'Data is kept only for as long as needed for the purposes described and for applicable legal, contractual, or legal-defence requirements, then deleted or anonymised where possible.\n\nTO BE DEFINED AND CONFIRMED: specific periods for accounts/profiles, vehicles, cases/accidents, photos/audio/documents, messages/requests, emails, technical logs, backups, and data following account closure.',
    ),
    _LegalSection(
      '9. Security',
      'The project provides authentication, authorisation controls, data access rules and, where implemented, protected or time-limited file access. Technical and organisational measures proportionate to risk are used, but no system can guarantee absolute security. The controller must confirm organisational measures, incident procedures, and production configurations.',
    ),
    _LegalSection(
      '10. Your rights',
      'Subject to applicable law, you may request information and access, correction of inaccurate data, deletion or restriction, objection, delivery or portability where available, and withdrawal of consent for the future. Rights may be limited by retention duties or other lawful grounds.',
    ),
    _LegalSection(
      '11. How to submit a request',
      'Email support@ciddigital.ch, stating the right you wish to exercise and the information needed to identify the account. A reasonable identity check may be required to protect the data. Requests will be handled within the time limits of applicable law. You may also contact the competent data protection authority.',
    ),
    _LegalSection(
      '12. Changes to this Privacy Policy',
      'This policy may be updated when the service, providers, or applicable obligations change. The version and update date identify the current text. Material changes will be communicated in an appropriate way.',
    ),
  ],
);

const _termsIt = _LegalDocumentCopy(
  title: 'Termini d’uso',
  eyebrow: 'CID Digitale · Area Cliente',
  summary:
      'Questi termini disciplinano l’accesso e l’uso del CID Cliente e delle funzioni collegate.',
  draftTitle: 'Validazione legale necessaria',
  draftBody:
      'La legge applicabile, il foro, l’identità completa del fornitore del servizio e l’eventuale limite economico di responsabilità non risultano definiti nel progetto e devono essere approvati da un consulente prima della pubblicazione.',
  lastUpdated:
      'Ultimo aggiornamento: 8 agosto 2026 · Versione $termsOfUseVersion',
  sections: [
    _LegalSection(
      '1. Natura e scopo del servizio',
      'CID Digitale offre strumenti per creare e gestire un profilo Cliente, veicoli, richieste di servizio e documentazione relativa a incidenti, oltre a facilitare comunicazioni con officine e assicurazioni coinvolte. La piattaforma è uno strumento operativo e non sostituisce consulenza legale, assicurativa, medica o professionale.',
    ),
    _LegalSection(
      '2. Registrazione e gestione dell’account',
      'L’utente deve fornire dati corretti, mantenere riservate le credenziali e informare tempestivamente il supporto in caso di accesso non autorizzato. L’account è personale, salvo funzioni che prevedano espressamente un uso per conto di terzi. L’utente è responsabile delle attività svolte tramite il proprio account nei limiti consentiti dalla legge.',
    ),
    _LegalSection(
      '3. Responsabilità sui dati inseriti',
      'L’utente è responsabile dell’esattezza, completezza e liceità dei dati inseriti o confermati, inclusi dati su persone, veicoli, assicurazioni, sinistri, firme, foto e documenti. Prima di caricare dati di terzi deve disporre delle autorizzazioni o di un’altra base valida. Le informazioni generate tramite OCR devono essere controllate e corrette dall’utente.',
    ),
    _LegalSection(
      '4. Uso corretto e divieto di abusi',
      'È vietato usare la piattaforma in modo illecito, fraudolento, ingannevole o lesivo; accedere senza autorizzazione a dati o account; aggirare controlli di sicurezza; introdurre codice dannoso; sovraccaricare il servizio; interferire con il suo funzionamento; impersonare terzi; caricare contenuti illeciti o violare diritti altrui.',
    ),
    _LegalSection(
      '5. Contenuti e documenti caricati',
      'L’utente conserva i diritti sui propri contenuti. Concede al fornitore del servizio le autorizzazioni tecniche limitate necessarie per ospitare, elaborare, convertire, trasmettere e rendere disponibili i contenuti secondo le funzioni richieste. L’utente deve conservare copie dei documenti importanti e non usare la piattaforma come unico archivio quando la legge o la prudenza richiedono un backup indipendente.',
    ),
    _LegalSection(
      '6. Comunicazioni con officine e assicurazioni',
      'La piattaforma può inoltrare dati e richieste ai destinatari coinvolti. Non garantisce che un’officina accetti una richiesta, che un’assicurazione riconosca una copertura o responsabilità, né che un destinatario risponda entro un determinato termine. L’utente deve verificare destinatari, allegati e stato delle comunicazioni e rispettare eventuali scadenze esterne.',
    ),
    _LegalSection(
      '7. Disponibilità e modifiche del servizio',
      'Il servizio viene fornito con ragionevole cura, ma può essere temporaneamente indisponibile per manutenzione, aggiornamenti, guasti, connettività o eventi fuori dal controllo del fornitore. Funzioni possono essere corrette, aggiornate o modificate per sicurezza, conformità o miglioramento, preservando per quanto ragionevole l’accesso ai dati dell’utente.',
    ),
    _LegalSection(
      '8. Garanzie e affidamento sulle informazioni',
      'Nei limiti consentiti dalla legge, non sono promessi funzionamento ininterrotto, assenza assoluta di errori o risultati assicurativi, legali o commerciali specifici. Mappe, OCR, ricerche di officine e dati di terzi possono essere incompleti o inesatti e devono essere verificati. Nessuna clausola esclude garanzie inderogabili previste dalla legge.',
    ),
    _LegalSection(
      '9. Sospensione o chiusura dell’account',
      'L’accesso può essere limitato o sospeso quando ragionevolmente necessario per sicurezza, manutenzione, violazioni dei termini, obblighi legali o protezione di utenti e terzi. Ove appropriato saranno considerate gravità, urgenza e possibilità di rimediare. L’utente può chiedere la chiusura dell’account contattando support@ciddigital.ch, ferme eventuali conservazioni obbligatorie.',
    ),
    _LegalSection(
      '10. Limitazione ragionevole di responsabilità',
      'Nei limiti consentiti dalla legge, il fornitore non risponde di perdite indirette o conseguenti né di danni causati da dati errati dell’utente, uso non autorizzato delle credenziali, decisioni di officine/assicurazioni o servizi esterni fuori dal proprio controllo. Restano impregiudicate le responsabilità che non possono essere escluse, in particolare per dolo o colpa grave ove applicabile.\n\nDA VERIFICARE LEGALMENTE: formulazione, validità e possibile limite economico secondo la legge applicabile.',
    ),
    _LegalSection(
      '11. Proprietà intellettuale',
      'Software, marchi, grafica, testi di sistema e altri elementi della piattaforma appartengono ai rispettivi titolari e sono protetti dalla legge. L’uso del servizio non trasferisce diritti di proprietà intellettuale. È vietato copiare, modificare, distribuire o sfruttare tali elementi oltre quanto consentito dalla legge o da un’autorizzazione scritta.',
    ),
    _LegalSection(
      '12. Privacy',
      'Il trattamento dei dati personali è descritto nella Privacy Policy, consultabile separatamente nella registrazione e nel profilo Cliente. Privacy Policy e Termini d’uso sono documenti distinti.',
    ),
    _LegalSection(
      '13. Modifiche ai termini',
      'I termini possono essere aggiornati per riflettere modifiche del servizio, requisiti di sicurezza o obblighi legali. Versione e data identificano il testo vigente. In caso di cambiamenti rilevanti sarà fornito un avviso adeguato e, quando necessario, richiesta una nuova accettazione.',
    ),
    _LegalSection(
      '14. Legge applicabile e foro',
      'DA VERIFICARE LEGALMENTE: la legge applicabile e il foro competente non sono definiti nel repository. La clausola dovrà rispettare le norme imperative e i diritti dei consumatori eventualmente applicabili.',
    ),
  ],
);

const _termsDe = _LegalDocumentCopy(
  title: 'Nutzungsbedingungen',
  eyebrow: 'CID Digitale · Kundenbereich',
  summary:
      'Diese Bedingungen regeln den Zugang zum CID-Kundenbereich und die Nutzung der verbundenen Funktionen.',
  draftTitle: 'Rechtliche Prüfung erforderlich',
  draftBody:
      'Anwendbares Recht, Gerichtsstand, vollständige Identität des Dienstanbieters und eine allfällige Haftungsobergrenze sind im Projekt nicht festgelegt und müssen vor der Veröffentlichung rechtlich genehmigt werden.',
  lastUpdated:
      'Letzte Aktualisierung: 8. August 2026 · Version $termsOfUseVersion',
  sections: [
    _LegalSection(
      '1. Art und Zweck des Dienstes',
      'CID Digitale bietet Werkzeuge zur Verwaltung von Kundenprofil, Fahrzeugen, Serviceanfragen und Unfallunterlagen und erleichtert die Kommunikation mit beteiligten Werkstätten und Versicherungen. Die Plattform ist ein Arbeitsmittel und ersetzt keine rechtliche, versicherungsbezogene, medizinische oder sonstige professionelle Beratung.',
    ),
    _LegalSection(
      '2. Registrierung und Kontoverwaltung',
      'Nutzende müssen richtige Angaben machen, Zugangsdaten vertraulich behandeln und unbefugte Zugriffe umgehend dem Support melden. Das Konto ist persönlich, ausser eine Funktion erlaubt ausdrücklich die Nutzung für Dritte. Im gesetzlich zulässigen Rahmen tragen Nutzende die Verantwortung für Aktivitäten über ihr Konto.',
    ),
    _LegalSection(
      '3. Verantwortung für eingegebene Daten',
      'Nutzende sind für Richtigkeit, Vollständigkeit und Rechtmässigkeit eingegebener oder bestätigter Daten verantwortlich, einschliesslich Angaben zu Personen, Fahrzeugen, Versicherungen, Unfällen, Unterschriften, Fotos und Dokumenten. Für Daten Dritter muss eine Erlaubnis oder andere gültige Grundlage bestehen. OCR-Ergebnisse müssen geprüft und korrigiert werden.',
    ),
    _LegalSection(
      '4. Zulässige Nutzung und Missbrauchsverbot',
      'Untersagt sind rechtswidrige, betrügerische, täuschende oder schädigende Nutzung; unbefugter Zugriff auf Daten oder Konten; Umgehung von Sicherheitskontrollen; Einschleusen schädlichen Codes; Überlastung oder Störung des Dienstes; Identitätstäuschung; rechtswidrige Inhalte und Verletzungen von Rechten Dritter.',
    ),
    _LegalSection(
      '5. Hochgeladene Inhalte und Dokumente',
      'Nutzende behalten ihre Rechte an eigenen Inhalten. Sie erteilen dem Dienstanbieter die begrenzten technischen Rechte, die zum Speichern, Verarbeiten, Konvertieren, Übermitteln und Bereitstellen gemäss den gewählten Funktionen erforderlich sind. Wichtige Dokumente sind zusätzlich zu sichern; die Plattform sollte nicht als einziges Archiv dienen, wenn Recht oder Sorgfalt eine unabhängige Sicherung verlangen.',
    ),
    _LegalSection(
      '6. Kommunikation mit Werkstätten und Versicherungen',
      'Die Plattform kann Daten und Anfragen an beteiligte Empfänger weiterleiten. Sie garantiert weder die Annahme durch eine Werkstatt noch Versicherungsdeckung, Haftungsanerkennung oder Antwort innerhalb einer bestimmten Frist. Nutzende müssen Empfänger, Anhänge und Kommunikationsstatus prüfen und externe Fristen einhalten.',
    ),
    _LegalSection(
      '7. Verfügbarkeit und Änderungen des Dienstes',
      'Der Dienst wird mit angemessener Sorgfalt erbracht, kann aber wegen Wartung, Updates, Störungen, Konnektivität oder Ereignissen ausserhalb der Kontrolle vorübergehend ausfallen. Funktionen können aus Sicherheits-, Compliance- oder Verbesserungsgründen korrigiert, aktualisiert oder geändert werden, wobei der Datenzugang soweit angemessen erhalten bleibt.',
    ),
    _LegalSection(
      '8. Gewährleistung und Vertrauen auf Informationen',
      'Soweit gesetzlich zulässig werden weder unterbrechungsfreier oder absolut fehlerfreier Betrieb noch bestimmte versicherungsrechtliche, rechtliche oder geschäftliche Ergebnisse zugesichert. Karten, OCR, Werkstattsuche und Drittinformationen können unvollständig oder falsch sein und müssen geprüft werden. Zwingende gesetzliche Gewährleistungen bleiben unberührt.',
    ),
    _LegalSection(
      '9. Sperrung oder Schliessung des Kontos',
      'Der Zugang kann eingeschränkt oder gesperrt werden, wenn dies für Sicherheit, Wartung, Verstösse, gesetzliche Pflichten oder den Schutz von Nutzenden und Dritten vernünftigerweise nötig ist. Soweit angemessen werden Schwere, Dringlichkeit und Abhilfemöglichkeiten berücksichtigt. Eine Kontoschliessung kann über support@ciddigital.ch verlangt werden; zwingende Aufbewahrungspflichten bleiben vorbehalten.',
    ),
    _LegalSection(
      '10. Angemessene Haftungsbegrenzung',
      'Soweit gesetzlich zulässig haftet der Anbieter nicht für indirekte oder Folgeschäden, die aus falschen Nutzerdaten, unbefugter Credential-Nutzung, Entscheidungen von Werkstätten/Versicherungen oder externen Diensten ausserhalb seiner Kontrolle entstehen. Nicht ausschliessbare Haftung, insbesondere für Vorsatz oder grobe Fahrlässigkeit soweit anwendbar, bleibt bestehen.\n\nRECHTLICH ZU PRÜFEN: Formulierung, Wirksamkeit und mögliche Haftungsobergrenze nach anwendbarem Recht.',
    ),
    _LegalSection(
      '11. Geistiges Eigentum',
      'Software, Marken, Gestaltung, Systemtexte und andere Plattformbestandteile gehören ihren jeweiligen Rechteinhabern und sind gesetzlich geschützt. Die Dienstnutzung überträgt keine Immaterialgüterrechte. Kopieren, Verändern, Verbreiten oder Verwerten ist ausserhalb gesetzlicher Erlaubnis oder schriftlicher Genehmigung untersagt.',
    ),
    _LegalSection(
      '12. Datenschutz',
      'Die Bearbeitung personenbezogener Daten ist in der separaten Datenschutzerklärung beschrieben, die bei der Registrierung und im Kundenprofil abrufbar ist. Datenschutzerklärung und Nutzungsbedingungen sind getrennte Dokumente.',
    ),
    _LegalSection(
      '13. Änderungen der Bedingungen',
      'Die Bedingungen können an Dienständerungen, Sicherheitsanforderungen oder rechtliche Pflichten angepasst werden. Version und Datum kennzeichnen den geltenden Text. Wesentliche Änderungen werden angemessen angekündigt; falls nötig wird eine erneute Zustimmung eingeholt.',
    ),
    _LegalSection(
      '14. Anwendbares Recht und Gerichtsstand',
      'RECHTLICH ZU PRÜFEN: Anwendbares Recht und Gerichtsstand sind im Repository nicht festgelegt. Die Klausel muss zwingendes Recht und allfällige Verbraucherrechte beachten.',
    ),
  ],
);

const _termsFr = _LegalDocumentCopy(
  title: 'Conditions d’utilisation',
  eyebrow: 'CID Digitale · Espace Client',
  summary:
      'Ces conditions régissent l’accès à l’espace Client CID et l’utilisation de ses fonctions associées.',
  draftTitle: 'Validation juridique nécessaire',
  draftBody:
      'Le droit applicable, le for, l’identité complète du fournisseur et une éventuelle limite financière de responsabilité ne sont pas définis dans le projet et doivent être validés juridiquement avant publication.',
  lastUpdated:
      'Dernière mise à jour : 8 août 2026 · Version $termsOfUseVersion',
  sections: [
    _LegalSection(
      '1. Nature et finalité du service',
      'CID Digitale propose des outils pour gérer un profil Client, des véhicules, des demandes de service et des documents liés aux accidents, et facilite les communications avec les ateliers et assurances concernés. La plateforme est un outil opérationnel et ne remplace aucun conseil juridique, assurantiel, médical ou professionnel.',
    ),
    _LegalSection(
      '2. Inscription et gestion du compte',
      'L’utilisateur doit fournir des données exactes, garder ses identifiants confidentiels et signaler rapidement tout accès non autorisé. Le compte est personnel, sauf fonction autorisant expressément un usage pour un tiers. Dans les limites légales, l’utilisateur répond des activités effectuées via son compte.',
    ),
    _LegalSection(
      '3. Responsabilité des données saisies',
      'L’utilisateur est responsable de l’exactitude, de l’exhaustivité et de la licéité des données saisies ou confirmées, notamment celles concernant personnes, véhicules, assurances, sinistres, signatures, photos et documents. Une autorisation ou autre base valable est nécessaire pour les données de tiers. Les résultats OCR doivent être contrôlés et corrigés.',
    ),
    _LegalSection(
      '4. Usage correct et interdiction des abus',
      'Il est interdit d’utiliser la plateforme de façon illicite, frauduleuse, trompeuse ou dommageable ; d’accéder sans autorisation à des données ou comptes ; de contourner la sécurité ; d’introduire du code malveillant ; de surcharger ou perturber le service ; d’usurper une identité ; de charger du contenu illicite ou de violer les droits d’autrui.',
    ),
    _LegalSection(
      '5. Contenus et documents téléversés',
      'L’utilisateur conserve ses droits sur ses contenus et accorde au fournisseur les autorisations techniques limitées nécessaires pour les héberger, traiter, convertir, transmettre et rendre disponibles selon les fonctions demandées. Il doit conserver une copie des documents importants et ne pas faire de la plateforme l’unique archive lorsqu’une sauvegarde indépendante est exigée par la loi ou la prudence.',
    ),
    _LegalSection(
      '6. Communications avec ateliers et assurances',
      'La plateforme peut transmettre données et demandes aux destinataires concernés. Elle ne garantit ni l’acceptation par un atelier, ni une couverture ou reconnaissance de responsabilité par une assurance, ni une réponse dans un délai donné. L’utilisateur doit vérifier destinataires, pièces jointes et statut des communications et respecter les délais externes.',
    ),
    _LegalSection(
      '7. Disponibilité et évolution du service',
      'Le service est fourni avec un soin raisonnable, mais peut être indisponible pour maintenance, mise à jour, panne, connectivité ou événement hors contrôle. Des fonctions peuvent être corrigées, mises à jour ou modifiées pour la sécurité, la conformité ou l’amélioration, tout en préservant raisonnablement l’accès aux données.',
    ),
    _LegalSection(
      '8. Garanties et fiabilité des informations',
      'Dans les limites légales, aucun fonctionnement ininterrompu ou absolument exempt d’erreurs ni aucun résultat assurantiel, juridique ou commercial précis n’est promis. Cartes, OCR, recherche d’ateliers et données tierces peuvent être incomplets ou inexacts et doivent être vérifiés. Les garanties impératives demeurent applicables.',
    ),
    _LegalSection(
      '9. Suspension ou fermeture du compte',
      'L’accès peut être limité ou suspendu lorsque cela est raisonnablement nécessaire pour la sécurité, la maintenance, une violation, une obligation légale ou la protection d’utilisateurs et de tiers. La gravité, l’urgence et les possibilités de remédier seront prises en compte lorsque pertinent. La fermeture peut être demandée à support@ciddigital.ch, sous réserve des conservations obligatoires.',
    ),
    _LegalSection(
      '10. Limitation raisonnable de responsabilité',
      'Dans les limites légales, le fournisseur n’est pas responsable des pertes indirectes ou consécutives ni des dommages dus à des données utilisateur erronées, à l’usage non autorisé d’identifiants, aux décisions d’ateliers/assurances ou à des services externes hors de son contrôle. Les responsabilités non excluables, notamment pour faute intentionnelle ou grave lorsque applicable, demeurent.\n\nÀ VÉRIFIER JURIDIQUEMENT : formulation, validité et éventuel plafond financier selon le droit applicable.',
    ),
    _LegalSection(
      '11. Propriété intellectuelle',
      'Logiciels, marques, graphismes, textes système et autres éléments appartiennent à leurs titulaires et sont protégés. L’usage du service ne transfère aucun droit de propriété intellectuelle. Toute copie, modification, distribution ou exploitation hors autorisation légale ou écrite est interdite.',
    ),
    _LegalSection(
      '12. Confidentialité',
      'Le traitement des données personnelles est décrit dans la Politique de confidentialité séparée, accessible lors de l’inscription et depuis le profil Client. La politique et les présentes conditions sont deux documents distincts.',
    ),
    _LegalSection(
      '13. Modifications des conditions',
      'Les conditions peuvent évoluer avec le service, les exigences de sécurité ou les obligations légales. La version et la date identifient le texte en vigueur. Les changements importants feront l’objet d’un avis approprié et, si nécessaire, d’une nouvelle acceptation.',
    ),
    _LegalSection(
      '14. Droit applicable et for',
      'À VÉRIFIER JURIDIQUEMENT : le droit applicable et le for ne sont pas définis dans le dépôt. La clause devra respecter les règles impératives et les droits des consommateurs éventuellement applicables.',
    ),
  ],
);

const _termsEn = _LegalDocumentCopy(
  title: 'Terms of Use',
  eyebrow: 'CID Digitale · Customer Area',
  summary:
      'These terms govern access to the CID Customer area and use of its connected features.',
  draftTitle: 'Legal validation required',
  draftBody:
      'Applicable law, jurisdiction, the service provider’s full identity, and any financial liability cap are not defined in the project and must be legally approved before publication.',
  lastUpdated: 'Last updated: 8 August 2026 · Version $termsOfUseVersion',
  sections: [
    _LegalSection(
      '1. Nature and purpose of the service',
      'CID Digitale provides tools for managing a Customer profile, vehicles, service requests, and accident-related documents, and facilitates communication with involved workshops and insurers. The platform is an operational tool and does not replace legal, insurance, medical, or other professional advice.',
    ),
    _LegalSection(
      '2. Registration and account management',
      'Users must provide accurate details, keep credentials confidential, and promptly notify support of unauthorised access. The account is personal unless a feature expressly permits acting for someone else. Users are responsible, to the extent permitted by law, for activity carried out through their account.',
    ),
    _LegalSection(
      '3. Responsibility for submitted data',
      'Users are responsible for the accuracy, completeness, and lawfulness of data they submit or confirm, including data about people, vehicles, insurance, accidents, signatures, photos, and documents. They must have permission or another valid basis before uploading third-party data. OCR-generated information must be reviewed and corrected by the user.',
    ),
    _LegalSection(
      '4. Acceptable use and prohibition of abuse',
      'The platform must not be used unlawfully, fraudulently, deceptively, or harmfully. Users must not access data or accounts without permission; bypass security controls; introduce malicious code; overload or disrupt the service; impersonate others; upload unlawful content; or infringe another person’s rights.',
    ),
    _LegalSection(
      '5. Uploaded content and documents',
      'Users retain rights in their content and grant the service provider the limited technical permissions needed to host, process, convert, transmit, and make it available through requested features. Users should retain copies of important documents and not rely on the platform as the only archive where law or prudent practice requires an independent backup.',
    ),
    _LegalSection(
      '6. Communications with workshops and insurers',
      'The platform may forward data and requests to involved recipients. It does not guarantee that a workshop will accept a request, an insurer will recognise coverage or liability, or a recipient will respond by a particular deadline. Users must check recipients, attachments, and communication status and comply with external deadlines.',
    ),
    _LegalSection(
      '7. Service availability and changes',
      'The service is provided with reasonable care but may be temporarily unavailable because of maintenance, updates, faults, connectivity, or events outside the provider’s control. Features may be fixed, updated, or changed for security, compliance, or improvement, while preserving reasonable access to user data where practicable.',
    ),
    _LegalSection(
      '8. Warranties and reliance on information',
      'To the extent permitted by law, uninterrupted or completely error-free operation and specific insurance, legal, or commercial outcomes are not promised. Maps, OCR, workshop search, and third-party data may be incomplete or inaccurate and must be checked. Nothing excludes warranties that cannot lawfully be excluded.',
    ),
    _LegalSection(
      '9. Account suspension or closure',
      'Access may be restricted or suspended where reasonably necessary for security, maintenance, terms violations, legal duties, or protection of users and third parties. Where appropriate, severity, urgency, and an opportunity to remedy will be considered. Users may request account closure at support@ciddigital.ch, subject to mandatory retention.',
    ),
    _LegalSection(
      '10. Reasonable limitation of liability',
      'To the extent permitted by law, the provider is not liable for indirect or consequential loss or harm caused by incorrect user data, unauthorised credential use, workshop/insurer decisions, or external services outside its control. Liability that cannot be excluded, including for intent or gross negligence where applicable, remains unaffected.\n\nLEGAL REVIEW REQUIRED: wording, enforceability, and any financial cap under the applicable law.',
    ),
    _LegalSection(
      '11. Intellectual property',
      'Software, trade marks, design, system text, and other platform elements belong to their respective rights holders and are legally protected. Using the service does not transfer intellectual property rights. Copying, modifying, distributing, or exploiting these elements beyond legal permission or written authorisation is prohibited.',
    ),
    _LegalSection(
      '12. Privacy',
      'Personal data processing is described in the separate Privacy Policy, available during registration and from the Customer profile. The Privacy Policy and Terms of Use are separate documents.',
    ),
    _LegalSection(
      '13. Changes to these terms',
      'The terms may be updated to reflect service changes, security needs, or legal obligations. The version and date identify the current text. Material changes will be notified appropriately and renewed acceptance will be requested where necessary.',
    ),
    _LegalSection(
      '14. Applicable law and jurisdiction',
      'LEGAL REVIEW REQUIRED: applicable law and jurisdiction are not defined in the repository. The clause must respect mandatory rules and any consumer rights that apply.',
    ),
  ],
);
