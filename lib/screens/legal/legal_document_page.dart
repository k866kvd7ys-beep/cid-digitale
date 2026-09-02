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
      'Questa informativa descrive come CID Digitale tratta i dati personali nell’Area Cliente e nei servizi collegati.',
  draftTitle: 'Documento in fase di revisione legale finale',
  draftBody:
      'Il testo riflette le funzioni e i fornitori verificati. Prima della versione legale definitiva devono essere validati l’identità e l’indirizzo completi del titolare, la futura struttura societaria, i periodi di conservazione proposti, le garanzie per i trasferimenti internazionali e, ove necessario, la legge applicabile e il foro competente.',
  lastUpdated:
      'Ultimo aggiornamento: 8 agosto 2026 · Versione $privacyPolicyVersion',
  sections: [
    _LegalSection(
      '1. Titolare del trattamento e contatti',
      'Il titolare del trattamento è l’attuale gestore del progetto CID Digitale, i cui dati completi devono essere inseriti prima della versione legale definitiva:\n\n[NOME O DENOMINAZIONE COMPLETA DEL TITOLARE ATTUALE]\n[INDIRIZZO COMPLETO]\n\nÈ prevista la futura costituzione di CID Digitale GmbH; tale società non è ancora costituita, non è iscritta al Registro di commercio e non viene indicata come attuale titolare. Denominazione legale, indirizzo, sede ed eventuali dati CHE/UID o del Registro di commercio saranno inseriti soltanto quando realmente disponibili.\n\nContatto per la privacy e per l’esercizio dei diritti: support@ciddigital.ch.',
    ),
    _LegalSection(
      '2. Dati trattati',
      'In base alle funzioni utilizzate, CID Digitale può trattare:\n\n• dati di account, autenticazione, profilo e contatto, come nome, cognome, e-mail, telefono e indirizzo;\n• dati dei veicoli, come targa, caratteristiche, numero di telaio/VIN quando utilizzato e documenti del veicolo;\n• dati assicurativi, come compagnia, riferimenti di polizza e informazioni necessarie alla gestione della pratica;\n• dati di pratiche e sinistri, come data, ora, luogo, coordinate GPS quando la funzione è usata, descrizione e dinamica, partecipanti, testimoni e informazioni inserite nel modulo CID;\n• dati relativi a persone ferite, inclusi dati anagrafici e di contatto e, quando l’utente compila i relativi campi, data di nascita, gravità indicata, zona del corpo interessata, soccorso sul posto, chiamata dell’ambulanza, eventuale trasporto e struttura ospedaliera e note libere;\n• fotografie, immagini, PDF, documenti, allegati, firme ove previste e dati estratti mediante OCR;\n• note testuali e registrazioni audio o note vocali create dall’utente; sui dispositivi supportati i file audio sono conservati localmente, possono essere riprodotti o rimossi mediante le funzioni disponibili e possono essere inclusi in una condivisione avviata volontariamente dall’utente;\n• dati codificati nei QR personali, che possono comprendere dati anagrafici e di contatto, indirizzo, dati del veicolo, targa, VIN, chilometraggio, prima immatricolazione, dati assicurativi, numero di polizza, numero di sinistro e numero cliente, in base ai campi compilati;\n• identificativi tecnici e informazioni collegate a QR, token o link di pratica, nella misura consentita dal relativo flusso;\n• messaggi e comunicazioni con officine e assicurazioni, richieste di appuntamento e di assistenza;\n• dati conservati localmente sul dispositivo o nel browser, tra cui profili QR, veicoli, pratiche o bozze con dati dei partecipanti, immagini, riferimenti a file audio, code di sincronizzazione e richieste di appuntamento non ancora trasmesse;\n• data, ora e versione delle accettazioni di Privacy Policy e Termini d’uso;\n• dati tecnici e di sicurezza necessari al funzionamento, alla protezione del servizio e alla diagnosi, inclusi i normali metadati di rete e delle richieste quando generati dai fornitori.\n\nQuando l’utente compila la sezione relativa alle persone ferite, CID Digitale tratta le informazioni inserite in modo strutturato nell’ambito della pratica. Questi dati non sono richiesti per ogni pratica, ma possono comprendere informazioni particolarmente sensibili. Devono essere inserite soltanto informazioni pertinenti e necessarie. La specifica condizione giuridica applicabile a tali informazioni deve essere confermata nella revisione legale finale e non viene dedotta dalla sola accettazione generale della Privacy Policy o dei Termini d’uso.\n\nLe copie locali sono distinte dai dati conservati nei sistemi remoti: possono risiedere nella memoria dell’applicazione, del dispositivo o del browser, anche mediante cache, archivi locali o code offline.',
    ),
    _LegalSection(
      '3. Finalità del trattamento',
      'I dati sono trattati per:\n\n• creare e gestire account, profilo Cliente e veicoli;\n• compilare, conservare, consultare e trasmettere pratiche CID e informazioni relative a incidenti e sinistri;\n• gestire fotografie, documenti e PDF ed estrarre, su richiesta, dati dai documenti mediante OCR;\n• registrare, riprodurre, conservare localmente, rimuovere mediante le funzioni disponibili ed eventualmente condividere note vocali quando l’utente utilizza la relativa funzione;\n• generare e leggere QR personali o di pratica e utilizzare token o link dedicati per importare informazioni o collegare l’utente al flusso richiesto;\n• conservare localmente dati e contenuti necessari alle funzioni offline, alle bozze, alle cache e alle code di sincronizzazione;\n• utilizzare posizione, indirizzo o area geografica per le funzioni richieste, come localizzazione e ricerca di officine;\n• trasmettere informazioni alle officine e alle assicurazioni coinvolte nel flusso scelto dall’utente;\n• gestire comunicazioni operative, e-mail di servizio, appuntamenti, richieste e assistenza;\n• mantenere sicurezza e continuità del servizio, prevenire abusi e diagnosticare problemi tecnici con dati ridotti al necessario;\n• adempiere a obblighi legali e accertare, esercitare o difendere diritti.',
    ),
    _LegalSection(
      '4. Basi giuridiche',
      'Nei limiti della legge applicabile, il trattamento si fonda sull’esecuzione del servizio richiesto e sulle misure precontrattuali; sul consenso quando richiesto; sull’adempimento di obblighi legali; e su interessi legittimi o privati prevalenti, in particolare sicurezza, prevenzione degli abusi, funzionamento del servizio e difesa di diritti, previa valutazione degli interessi coinvolti. Per eventuali informazioni particolarmente delicate vengono applicate anche le condizioni ulteriori richieste dalla legge.\n\nLa corrispondenza definitiva tra singole finalità e basi giuridiche, compresa l’eventuale applicazione del GDPR oltre al diritto svizzero, resta soggetta a revisione legale finale.',
    ),
    _LegalSection(
      '5. Fornitori tecnici e trattamenti verificati',
      'Per erogare il servizio vengono utilizzati i seguenti fornitori o componenti verificati:\n\n• Supabase: autenticazione, database, Storage, Edge Functions e servizi backend. Il progetto Production è configurato nella regione West EU (Irlanda, eu-west-1). Può ricevere e conservare le categorie di dati applicativi descritte in questa informativa;\n• Vercel: hosting e distribuzione del frontend web, infrastruttura di deployment e log tecnici con i normali dati delle richieste; non è il database applicativo del servizio;\n• Resend: invio di e-mail operative. Riceve gli indirizzi di mittente e destinatario, oggetto, contenuto necessario del messaggio e, quando previsto dal flusso, allegati o documenti e dati della pratica necessari all’e-mail;\n• Google Places: ricerca di luoghi e officine. Può ricevere termini di ricerca, coordinate o area geografica, lingua/locale e normali informazioni tecniche della richiesta;\n• Google Maps: viene aperto mediante un collegamento esterno quando l’utente sceglie la relativa funzione. Google riceve la query di ricerca e i normali dati tecnici della connessione; l’eventuale utilizzo della posizione è gestito da Google e dal dispositivo o browser secondo le relative impostazioni;\n• OpenStreetMap/Nominatim: geocodifica inversa. Riceve le coordinate precise da convertire in indirizzo. Nel flusso verificato non vengono intenzionalmente aggiunti nome, e-mail, targa, dati assicurativi o identificativo della pratica;\n• Google ML Kit: riconoscimento OCR sul dispositivo nelle piattaforme supportate. Le immagini e il testo vengono elaborati localmente; il componente può effettuare comunicazioni tecniche o download dei modelli previsti dalla piattaforma, ma non è presentato come destinatario delle immagini;\n• Google Cloud Vision: nel backend è disponibile la Edge Function ocr-libretto-cloud, ma non risulta richiamata dal flusso Cliente attivo verificato. Non viene quindi descritta come trattamento ordinario corrente; un’eventuale attivazione richiederà una nuova verifica privacy;\n• Tesseract.js e jsDelivr: il flusso OCR Cliente attivo verificato non invia documenti a Tesseract.js. La versione web carica tuttavia la libreria Tesseract.js da jsDelivr all’apertura dell’app; il CDN può ricevere i normali dati tecnici associati alla richiesta HTTP, ma nel flusso Cliente attivo verificato non vengono intenzionalmente inviati a jsDelivr immagini, documenti o testo OCR.\n\nDettagli non accertabili dal progetto, come tutti i sottofornitori, tempi dei log dei fornitori e configurazioni interne, devono essere validati sulla documentazione e sugli accordi contrattuali aggiornati.',
    ),
    _LegalSection(
      '6. Officine, assicurazioni e altri destinatari',
      'I dati sono condivisi solo nella misura necessaria con l’officina selezionata o coinvolta, l’assicurazione competente o coinvolta, i fornitori tecnici necessari e, quando previsto dalla legge, autorità, consulenti o altri soggetti autorizzati. L’invio a un’officina o a un’assicurazione dipende dalla richiesta e dal flusso scelto dall’utente. Quando l’utente utilizza il menu di condivisione del dispositivo, file e informazioni, incluse eventuali note vocali, vengono trasmessi soltanto al destinatario o al servizio selezionato volontariamente dall’utente; il trattamento successivo dipende da tale destinatario o servizio.\n\nOfficine e assicurazioni possono trattare i dati sotto la propria responsabilità e secondo i propri obblighi e periodi di conservazione. La cancellazione presso CID Digitale non comporta automaticamente la cancellazione delle copie già trasmesse a tali destinatari; le relative richieste possono dover essere rivolte direttamente a loro.',
    ),
    _LegalSection(
      '7. Ubicazione e trasferimenti dei dati',
      'Il database Supabase di Production è configurato in Irlanda (West EU, eu-west-1). In base al fornitore, ai suoi sottofornitori e alla funzione utilizzata, dati o metadati tecnici possono essere trattati anche in Svizzera, nello Spazio economico europeo o in altri Paesi. Resend e altri fornitori possono implicare trattamenti internazionali.\n\nQuando richiesto, CID Digitale deve applicare garanzie adeguate per i trasferimenti internazionali. Paesi, sottofornitori e meccanismi contrattuali definitivi devono essere verificati sugli accordi e sulle configurazioni di produzione prima della versione legale finale; questa informativa non presume dettagli non confermati.',
    ),
    _LegalSection(
      '8. Conservazione dei dati',
      'I periodi definitivi di conservazione non sono ancora approvati e non vengono presentati come scadenze tecnicamente garantite. Il repository non consente di verificare una politica automatica e uniforme per tutte le categorie. Prima della versione legale definitiva devono essere approvati e verificati periodi distinti almeno per:\n\n• account e profilo Cliente;\n• veicoli e dati assicurativi associati al profilo;\n• bozze locali e bozze remote;\n• pratiche CID e sinistri definitivi;\n• fotografie, documenti, PDF, firme, registrazioni audio e altri allegati;\n• chat e comunicazioni collegate alle pratiche;\n• appuntamenti e richieste alle officine;\n• richieste di supporto;\n• log tecnici e di sicurezza;\n• backup e copie gestite dai fornitori;\n• cache, code offline e altri dati conservati localmente sul dispositivo o nel browser.\n\nFino a tale approvazione, i dati possono essere conservati per il tempo necessario alle finalità per cui sono trattati e agli obblighi o interessi legittimi applicabili, senza che questa formulazione garantisca una cancellazione automatica entro un termine fisso. Obblighi legali, controversie, accertamento o difesa di diritti e diritti di terzi possono richiedere la conservazione di determinati dati.\n\nLe copie locali sono gestite separatamente dai dati remoti. Il logout, la chiusura dell’account o la cancellazione dei dati dai sistemi remoti non eliminano necessariamente cache, bozze, code offline, immagini, profili QR, veicoli o file audio presenti sul dispositivo o nel browser. L’utente deve utilizzare le funzioni di eliminazione disponibili e, quando necessario, rimuovere i dati dell’applicazione o del sito dal proprio dispositivo. Anche le copie già trasmesse a officine o assicurazioni restano soggette agli obblighi e ai periodi applicati da tali destinatari.',
    ),
    _LegalSection(
      '9. Sicurezza',
      'CID Digitale adotta misure tecniche e organizzative ragionevoli e proporzionate al rischio, tra cui autenticazione, controlli di accesso, separazione dei ruoli, policy di accesso ai dati, cifratura delle comunicazioni in transito, minimizzazione e riduzione o sanitizzazione dei log. Accessi e autorizzazioni sono limitati in funzione del servizio e del ruolo.\n\nNessun sistema può garantire sicurezza assoluta. Procedure organizzative, gestione degli incidenti e configurazioni di produzione devono essere riesaminate periodicamente.',
    ),
    _LegalSection(
      '10. Diritti dell’interessato',
      'Nei limiti della legge applicabile puoi chiedere informazioni sul trattamento e accesso ai dati, rettifica, cancellazione, limitazione o opposizione, nonché consegna o portabilità quando prevista. Puoi revocare un consenso per il futuro senza pregiudicare la liceità del trattamento precedente alla revoca. Puoi inoltre presentare reclamo all’autorità di protezione dei dati competente.\n\nQuesti diritti non sono assoluti: obblighi legali, necessità di conservazione, diritti di terzi o esigenze di accertamento e difesa possono giustificare una limitazione o il mantenimento di determinati dati.',
    ),
    _LegalSection(
      '11. Come presentare una richiesta',
      'Invia la richiesta a support@ciddigital.ch indicando il diritto che vuoi esercitare e le informazioni strettamente necessarie per identificare l’account o i dati interessati. Per proteggere le informazioni può essere richiesta una verifica ragionevole dell’identità. CID Digitale risponderà nei termini previsti dalla legge applicabile. Per dati già trasmessi a officine o assicurazioni, può essere necessario contattare anche tali destinatari.',
    ),
    _LegalSection(
      '12. Privacy by design e minimizzazione',
      'CID Digitale mira a raccogliere e condividere solo i dati necessari alla funzione scelta, a limitare gli accessi per ruolo e a evitare nei log contenuti personali, token, payload, coordinate, documenti OCR o risposte complete dei servizi. L’utente è invitato a non inserire informazioni eccedenti, a verificare i destinatari prima della trasmissione e a condividere QR, token e link soltanto con i destinatari previsti. Chi dispone di un QR personale, token o link può leggere o utilizzare le informazioni consentite dal relativo flusso.',
    ),
    _LegalSection(
      '13. Modifiche e versione della Privacy Policy',
      'Questa informativa può essere aggiornata quando cambiano il servizio, i fornitori, i trattamenti o gli obblighi applicabili. La data e la versione indicate identificano il testo vigente. Le modifiche sostanziali saranno comunicate in modo adeguato e, quando richiesto, potrà essere domandata una nuova accettazione.',
    ),
  ],
);

const _privacyDe = _LegalDocumentCopy(
  title: 'Datenschutzerklärung',
  eyebrow: 'CID Digitale · Kundenbereich',
  summary:
      'Diese Erklärung beschreibt, wie CID Digitale personenbezogene Daten im Kundenbereich und in den verbundenen Diensten bearbeitet.',
  draftTitle: 'Dokument in abschliessender rechtlicher Prüfung',
  draftBody:
      'Der Text entspricht den geprüften Funktionen und Anbietern. Vor der endgültigen rechtlichen Fassung sind die vollständige Identität und Anschrift des Verantwortlichen, die künftige Gesellschaftsstruktur, die vorgeschlagenen Aufbewahrungsfristen, Garantien für internationale Datenübermittlungen sowie gegebenenfalls anwendbares Recht und Gerichtsstand zu validieren.',
  lastUpdated:
      'Letzte Aktualisierung: 8. August 2026 · Version $privacyPolicyVersion',
  sections: [
    _LegalSection(
      '1. Verantwortlicher und Kontakt',
      'Verantwortlicher ist der Betreiber von CID Digitale. Die künftige Gründung der CID Digitale GmbH ist vorgesehen; diese Gesellschaft ist noch nicht gegründet und wird nicht als derzeitige Verantwortliche bezeichnet. Die vollständige juristische Bezeichnung, Anschrift und allfällige Angaben des schweizerischen Handelsregisters werden nach der Gründung ergänzt und müssen vor der endgültigen rechtlichen Fassung vervollständigt werden.\n\nKontakt für Datenschutzfragen und zur Ausübung von Rechten: support@ciddigital.ch.',
    ),
    _LegalSection(
      '2. Bearbeitete Daten',
      'Je nach genutzter Funktion kann CID Digitale folgende Daten bearbeiten:\n\n• Konto-, Authentifizierungs-, Profil- und Kontaktdaten wie Vorname, Nachname, E-Mail-Adresse, Telefonnummer und Anschrift;\n• Fahrzeugdaten wie Kennzeichen, Merkmale, Fahrgestellnummer/VIN, sofern verwendet, und Fahrzeugdokumente;\n• Versicherungsdaten wie Gesellschaft, Policenangaben und für die Fallbearbeitung erforderliche Informationen;\n• Fall- und Unfalldaten wie Datum, Uhrzeit, Ort, GPS-Koordinaten bei Nutzung dieser Funktion, Beschreibung und Hergang, Beteiligte, Zeugen, allfällige verletzte Personen und Angaben im CID-Formular;\n• Fotos, Bilder, PDF-Dateien, Dokumente, Anhänge, gegebenenfalls Unterschriften und mittels OCR erkannte Daten;\n• Nachrichten und Kommunikation mit Werkstätten und Versicherungen, Termin- und Supportanfragen;\n• Datum, Uhrzeit und Version der Zustimmung zur Datenschutzerklärung und zu den Nutzungsbedingungen;\n• für Betrieb, Schutz und Diagnose erforderliche technische und sicherheitsbezogene Daten, einschliesslich üblicher Netzwerk- und Anfragemetadaten, wenn diese von Anbietern erzeugt werden.\n\nEin Fall kann ausnahmsweise besonders schützenswerte Informationen enthalten, etwa Hinweise auf verletzte Personen. CID Digitale gibt nicht an, systematisch Gesundheitsdaten zu erheben. Nutzende sollen nur relevante und erforderliche Informationen eingeben.',
    ),
    _LegalSection(
      '3. Bearbeitungszwecke',
      'Die Daten werden bearbeitet, um:\n\n• Konten, Kundenprofile und Fahrzeuge zu erstellen und zu verwalten;\n• CID-Fälle sowie Unfall- und Schadeninformationen auszufüllen, aufzubewahren, einzusehen und zu übermitteln;\n• Fotos, Dokumente und PDF-Dateien zu verwalten und auf Wunsch Daten mittels OCR daraus zu erkennen;\n• Standort, Anschrift oder geografisches Gebiet für angeforderte Funktionen wie Lokalisierung und Werkstattsuche zu verwenden;\n• Informationen an die am gewählten Ablauf beteiligten Werkstätten und Versicherungen zu übermitteln;\n• betriebliche Mitteilungen, Service-E-Mails, Termine, Anfragen und Support zu bearbeiten;\n• Sicherheit und Verfügbarkeit des Dienstes zu erhalten, Missbrauch zu verhindern und technische Probleme mit auf das Nötige beschränkten Daten zu diagnostizieren;\n• gesetzliche Pflichten zu erfüllen und Rechte festzustellen, auszuüben oder zu verteidigen.',
    ),
    _LegalSection(
      '4. Rechtsgrundlagen',
      'Im Rahmen des anwendbaren Rechts stützt sich die Bearbeitung auf die Erfüllung des angeforderten Dienstes und vorvertragliche Massnahmen, auf eine Einwilligung, soweit erforderlich, auf gesetzliche Pflichten sowie auf überwiegende berechtigte oder private Interessen, insbesondere Sicherheit, Missbrauchsprävention, Betrieb des Dienstes und Rechtsverteidigung, nach Abwägung der betroffenen Interessen. Für allfällige besonders schützenswerte Informationen gelten zusätzlich die gesetzlich verlangten Voraussetzungen.\n\nDie endgültige Zuordnung der einzelnen Zwecke zu den Rechtsgrundlagen, einschliesslich einer möglichen Anwendbarkeit der DSGVO zusätzlich zum schweizerischen Recht, bleibt der abschliessenden rechtlichen Prüfung vorbehalten.',
    ),
    _LegalSection(
      '5. Geprüfte technische Anbieter und Bearbeitungen',
      'Zur Erbringung des Dienstes werden folgende geprüfte Anbieter oder Komponenten eingesetzt:\n\n• Supabase: Authentifizierung, Datenbank, Storage, Edge Functions und Backend-Dienste. Das Production-Projekt ist in der Region West EU (Irland, eu-west-1) konfiguriert. Es kann die in dieser Erklärung beschriebenen Kategorien von Anwendungsdaten empfangen und speichern;\n• Vercel: Hosting und Bereitstellung des Web-Frontends, Deployment-Infrastruktur und technische Protokolle mit üblichen Anfragedaten; Vercel ist nicht die Anwendungsdatenbank des Dienstes;\n• Resend: Versand betrieblicher E-Mails. Verarbeitet werden Absender- und Empfängeradresse, Betreff, notwendiger Nachrichteninhalt sowie, wenn im Ablauf vorgesehen, Anhänge oder Dokumente und für die E-Mail notwendige Falldaten;\n• Google Places: Suche nach Orten und Werkstätten. Übermittelt werden können Suchbegriffe, Koordinaten oder geografisches Gebiet, Sprache/Locale und übliche technische Anfragedaten;\n• OpenStreetMap/Nominatim: Rückwärtsgeokodierung. Übermittelt werden die genauen Koordinaten, die in eine Anschrift umgewandelt werden. Im geprüften Ablauf werden Name, E-Mail-Adresse, Kennzeichen, Versicherungsdaten oder Fallkennung nicht absichtlich hinzugefügt;\n• Google ML Kit: OCR-Texterkennung auf dem Gerät auf unterstützten Plattformen. Bilder und Text werden lokal bearbeitet. Die Komponente kann technische Kommunikation oder plattformseitige Modell-Downloads ausführen, wird aber nicht als Empfängerin der Bilder dargestellt;\n• Google Cloud Vision: Im Backend ist die Edge Function ocr-libretto-cloud verfügbar, wird jedoch im geprüften aktiven Kundenablauf nicht aufgerufen. Sie wird deshalb nicht als reguläre aktuelle Bearbeitung beschrieben; eine Aktivierung erfordert eine neue Datenschutzprüfung;\n• Tesseract.js: technisch vorhandene Abhängigkeit, die im geprüften aktiven OCR-Kundenablauf nicht verwendet wird. Sie gilt nicht als aktuelle Empfängerin von Dokumenten.\n\nAus dem Projekt nicht abschliessend feststellbare Details wie sämtliche Unterauftragsbearbeiter, Protokollfristen der Anbieter und interne Konfigurationen müssen anhand aktueller Dokumentation und Vereinbarungen validiert werden.',
    ),
    _LegalSection(
      '6. Werkstätten, Versicherungen und weitere Empfänger',
      'Daten werden nur im erforderlichen Umfang an die ausgewählte oder beteiligte Werkstatt, den zuständigen oder beteiligten Versicherer, notwendige technische Anbieter sowie – soweit gesetzlich vorgesehen – Behörden, Berater oder andere befugte Stellen weitergegeben. Die Übermittlung an eine Werkstatt oder Versicherung hängt von der Anfrage und dem von den Nutzenden gewählten Ablauf ab.\n\nWerkstätten und Versicherer können die Daten eigenverantwortlich und nach ihren eigenen Pflichten und Aufbewahrungsfristen bearbeiten. Eine Löschung bei CID Digitale bewirkt nicht automatisch die Löschung bereits übermittelter Kopien bei diesen Empfängern; entsprechende Anträge müssen gegebenenfalls direkt an sie gerichtet werden.',
    ),
    _LegalSection(
      '7. Bearbeitungsorte und Datenübermittlungen',
      'Die Supabase-Production-Datenbank ist in Irland (West EU, eu-west-1) konfiguriert. Abhängig vom Anbieter, seinen Unterauftragsbearbeitern und der genutzten Funktion können Daten oder technische Metadaten auch in der Schweiz, im Europäischen Wirtschaftsraum oder in anderen Ländern bearbeitet werden. Resend und weitere Anbieter können internationale Bearbeitungen mit sich bringen.\n\nSoweit erforderlich, muss CID Digitale geeignete Garantien für internationale Datenübermittlungen anwenden. Die endgültigen Länder, Unterauftragsbearbeiter und vertraglichen Mechanismen sind vor der endgültigen rechtlichen Fassung anhand der Vereinbarungen und Produktionskonfigurationen zu prüfen; diese Erklärung unterstellt keine unbestätigten Einzelheiten.',
    ),
    _LegalSection(
      '8. Vorgeschlagene Aufbewahrungsfristen',
      'Die folgende betriebliche Regelung ist ein Vorschlag, der einer abschliessenden rechtlichen und technischen Prüfung unterliegt:\n\n• Konto und Profil: für die Dauer des Kontos; nach einem gültigen Löschungsantrag normalerweise Löschung oder Anonymisierung innerhalb von 30 Tagen, ausser bei gesetzlichen Pflichten, Streitigkeiten oder einer anderen gerechtfertigten Grundlage;\n• Fahrzeuge und Versicherungsdaten im Profil: solange für den Dienst erforderlich oder bis zur Löschung, mit denselben Ausnahmen;\n• CID-Fälle, Schäden, Fotos, Dokumente, Unterschriften und Anhänge: 10 Jahre nach Abschluss des Falls;\n• fallbezogene Chats und Kommunikation: derselbe vorgeschlagene Zeitraum von 10 Jahren;\n• Termine und Werkstattanfragen ohne Bezug zu einem Versicherungsfall: 2 Jahre nach Abschluss oder Stornierung;\n• Supportanfragen: 2 Jahre nach Abschluss;\n• technische und sicherheitsbezogene Protokolle: normalerweise höchstens 12 Monate, ausser bei Sicherheits-, Untersuchungs- oder gesetzlichen Erfordernissen;\n• Sicherungskopien: unverbindlicher Höchstwert von 90 Tagen, technisch zu bestätigen und nicht als bereits geprüfte Funktion zu verstehen.\n\nFristen können im erforderlichen Umfang für gesetzliche Pflichten, die Feststellung oder Verteidigung von Rechten und Streitigkeiten verlängert werden. Danach werden Daten gelöscht oder anonymisiert, soweit dies technisch und rechtlich möglich ist.',
    ),
    _LegalSection(
      '9. Sicherheit',
      'CID Digitale setzt angemessene, dem Risiko entsprechende technische und organisatorische Massnahmen ein, darunter Authentifizierung, Zugriffskontrollen, Rollentrennung, Datenzugriffsrichtlinien, Verschlüsselung der Übertragung, Datenminimierung sowie reduzierte oder bereinigte Protokolle. Zugriffe und Berechtigungen werden entsprechend Dienst und Rolle beschränkt.\n\nKein System kann absolute Sicherheit garantieren. Organisatorische Verfahren, Vorfallmanagement und Produktionskonfigurationen müssen regelmässig überprüft werden.',
    ),
    _LegalSection(
      '10. Rechte betroffener Personen',
      'Im Rahmen des anwendbaren Rechts kannst du Informationen über die Bearbeitung und Zugang zu Daten, Berichtigung, Löschung, Einschränkung oder Widerspruch sowie Herausgabe oder Übertragbarkeit, soweit vorgesehen, verlangen. Eine Einwilligung kann für die Zukunft widerrufen werden, ohne die Rechtmässigkeit der vorherigen Bearbeitung zu berühren. Du kannst zudem bei der zuständigen Datenschutzbehörde Beschwerde einreichen.\n\nDiese Rechte gelten nicht uneingeschränkt: Gesetzliche Pflichten, Aufbewahrungserfordernisse, Rechte Dritter oder die Feststellung und Verteidigung von Ansprüchen können Einschränkungen oder die weitere Aufbewahrung bestimmter Daten rechtfertigen.',
    ),
    _LegalSection(
      '11. So stellst du eine Anfrage',
      'Sende deine Anfrage an support@ciddigital.ch und nenne das auszuübende Recht sowie nur die Angaben, die zur Identifikation des Kontos oder der betroffenen Daten erforderlich sind. Zum Schutz der Informationen kann eine angemessene Identitätsprüfung verlangt werden. CID Digitale antwortet innerhalb der Fristen des anwendbaren Rechts. Für bereits an Werkstätten oder Versicherer übermittelte Daten kann es erforderlich sein, auch diese Empfänger zu kontaktieren.',
    ),
    _LegalSection(
      '12. Privacy by Design und Datenminimierung',
      'CID Digitale ist darauf ausgerichtet, nur die für die gewählte Funktion erforderlichen Daten zu erheben und weiterzugeben, Zugriffe nach Rollen zu beschränken und personenbezogene Inhalte, Token, Payloads, Koordinaten, OCR-Dokumente oder vollständige Dienstantworten in Protokollen zu vermeiden. Nutzende sollen keine überschüssigen Informationen eingeben und die Empfänger vor einer Übermittlung prüfen.',
    ),
    _LegalSection(
      '13. Änderungen und Version der Datenschutzerklärung',
      'Diese Erklärung kann aktualisiert werden, wenn sich Dienst, Anbieter, Bearbeitungen oder anwendbare Pflichten ändern. Datum und Version kennzeichnen den geltenden Text. Wesentliche Änderungen werden angemessen mitgeteilt; soweit erforderlich, kann eine erneute Zustimmung verlangt werden.',
    ),
  ],
);

const _privacyFr = _LegalDocumentCopy(
  title: 'Politique de confidentialité',
  eyebrow: 'CID Digitale · Espace Client',
  summary:
      'La présente politique décrit comment CID Digitale traite les données personnelles dans l’espace Client et les services associés.',
  draftTitle: 'Document en cours de révision juridique finale',
  draftBody:
      'Le texte reflète les fonctions et fournisseurs vérifiés. Avant la version juridique définitive, il faut valider l’identité et l’adresse complètes du responsable, la future structure sociétaire, les durées de conservation proposées, les garanties relatives aux transferts internationaux et, le cas échéant, le droit applicable et le for.',
  lastUpdated:
      'Dernière mise à jour : 8 août 2026 · Version $privacyPolicyVersion',
  sections: [
    _LegalSection(
      '1. Responsable du traitement et contact',
      'Le responsable du traitement est l’exploitant de CID Digitale. La constitution future de CID Digitale GmbH est prévue ; cette société n’existe pas encore et n’est pas désignée comme responsable actuel. La dénomination juridique complète, l’adresse et les éventuelles données du registre du commerce suisse seront ajoutées après la constitution et doivent être complétées avant la version juridique définitive.\n\nContact pour la protection des données et l’exercice des droits : support@ciddigital.ch.',
    ),
    _LegalSection(
      '2. Données traitées',
      'Selon les fonctions utilisées, CID Digitale peut traiter :\n\n• des données de compte, d’authentification, de profil et de contact, telles que prénom, nom, e-mail, téléphone et adresse ;\n• des données de véhicule, telles que plaque d’immatriculation, caractéristiques, numéro de châssis/VIN lorsqu’il est utilisé et documents du véhicule ;\n• des données d’assurance, telles que compagnie, références de police et informations nécessaires à la gestion du dossier ;\n• des données de dossiers et de sinistres, telles que date, heure, lieu, coordonnées GPS lorsque cette fonction est utilisée, description et circonstances, participants, témoins, éventuelles personnes blessées et informations saisies dans le constat CID ;\n• des photographies, images, PDF, documents, pièces jointes, signatures le cas échéant et données extraites par OCR ;\n• des messages et communications avec les ateliers et assurances, demandes de rendez-vous et d’assistance ;\n• la date, l’heure et la version des acceptations de la Politique de confidentialité et des Conditions d’utilisation ;\n• des données techniques et de sécurité nécessaires au fonctionnement, à la protection et au diagnostic, y compris les métadonnées usuelles du réseau et des requêtes lorsqu’elles sont générées par les fournisseurs.\n\nUn dossier peut exceptionnellement contenir des informations particulièrement sensibles, par exemple des mentions de personnes blessées. CID Digitale ne déclare pas collecter systématiquement des données de santé : l’utilisateur ne doit saisir que les informations pertinentes et nécessaires.',
    ),
    _LegalSection(
      '3. Finalités du traitement',
      'Les données sont traitées pour :\n\n• créer et gérer les comptes, profils Client et véhicules ;\n• compléter, conserver, consulter et transmettre les dossiers CID et les informations relatives aux accidents et sinistres ;\n• gérer les photographies, documents et PDF et, à la demande, en extraire des données par OCR ;\n• utiliser la position, l’adresse ou la zone géographique pour les fonctions demandées, telles que la localisation et la recherche d’ateliers ;\n• transmettre des informations aux ateliers et assurances concernés par le parcours choisi par l’utilisateur ;\n• gérer les communications opérationnelles, e-mails de service, rendez-vous, demandes et assistance ;\n• maintenir la sécurité et la continuité du service, prévenir les abus et diagnostiquer les problèmes techniques avec des données limitées au nécessaire ;\n• respecter les obligations légales et constater, exercer ou défendre des droits.',
    ),
    _LegalSection(
      '4. Bases juridiques',
      'Dans les limites du droit applicable, le traitement repose sur l’exécution du service demandé et les mesures précontractuelles, sur le consentement lorsqu’il est requis, sur le respect d’obligations légales et sur des intérêts légitimes ou privés prépondérants, notamment la sécurité, la prévention des abus, le fonctionnement du service et la défense de droits, après mise en balance des intérêts concernés. Des conditions légales supplémentaires sont appliquées aux éventuelles informations particulièrement sensibles.\n\nL’association définitive de chaque finalité à sa base juridique, y compris l’éventuelle application du RGPD en plus du droit suisse, reste soumise à la révision juridique finale.',
    ),
    _LegalSection(
      '5. Fournisseurs techniques et traitements vérifiés',
      'Les fournisseurs ou composants vérifiés suivants sont utilisés pour fournir le service :\n\n• Supabase : authentification, base de données, Storage, Edge Functions et services backend. Le projet Production est configuré dans la région West EU (Irlande, eu-west-1). Il peut recevoir et conserver les catégories de données applicatives décrites dans la présente politique ;\n• Vercel : hébergement et distribution du frontend web, infrastructure de déploiement et journaux techniques contenant les données usuelles des requêtes ; Vercel n’est pas la base de données applicative du service ;\n• Resend : envoi d’e-mails opérationnels. Sont transmis les adresses d’expéditeur et de destinataire, l’objet, le contenu nécessaire du message et, lorsque le parcours le prévoit, des pièces jointes ou documents et les données du dossier nécessaires à l’e-mail ;\n• Google Places : recherche de lieux et d’ateliers. Peuvent être transmis les termes de recherche, les coordonnées ou la zone géographique, la langue/locale et les informations techniques usuelles de la requête ;\n• OpenStreetMap/Nominatim : géocodage inverse. Les coordonnées précises à convertir en adresse sont transmises. Dans le parcours vérifié, le nom, l’e-mail, la plaque, les données d’assurance ou l’identifiant du dossier ne sont pas ajoutés intentionnellement ;\n• Google ML Kit : reconnaissance OCR sur l’appareil sur les plateformes prises en charge. Les images et le texte sont traités localement ; le composant peut effectuer des communications techniques ou télécharger les modèles prévus par la plateforme, mais il n’est pas présenté comme destinataire des images ;\n• Google Cloud Vision : la fonction Edge ocr-libretto-cloud est disponible dans le backend, mais elle n’est pas appelée par le parcours Client actif vérifié. Elle n’est donc pas décrite comme un traitement courant ; son activation exigerait une nouvelle évaluation de confidentialité ;\n• Tesseract.js : dépendance technique présente, mais non utilisée dans le parcours OCR Client actif vérifié. Elle n’est pas considérée comme un destinataire actuel des documents.\n\nLes éléments qui ne peuvent pas être établis définitivement à partir du projet, tels que tous les sous-traitants ultérieurs, les durées des journaux des fournisseurs et leurs configurations internes, doivent être validés au moyen de la documentation et des accords à jour.',
    ),
    _LegalSection(
      '6. Ateliers, assurances et autres destinataires',
      'Les données ne sont partagées que dans la mesure nécessaire avec l’atelier sélectionné ou concerné, l’assureur compétent ou concerné, les fournisseurs techniques nécessaires et, lorsque la loi le prévoit, les autorités, conseillers ou autres personnes autorisées. La transmission à un atelier ou à une assurance dépend de la demande et du parcours choisi par l’utilisateur.\n\nLes ateliers et assurances peuvent traiter les données sous leur propre responsabilité, selon leurs obligations et leurs propres durées de conservation. La suppression chez CID Digitale n’entraîne pas automatiquement la suppression des copies déjà transmises à ces destinataires ; les demandes correspondantes peuvent devoir leur être adressées directement.',
    ),
    _LegalSection(
      '7. Lieu du traitement et transferts',
      'La base de données Supabase Production est configurée en Irlande (West EU, eu-west-1). Selon le fournisseur, ses sous-traitants ultérieurs et la fonction utilisée, des données ou métadonnées techniques peuvent aussi être traitées en Suisse, dans l’Espace économique européen ou dans d’autres pays. Resend et d’autres fournisseurs peuvent impliquer des traitements internationaux.\n\nLorsque cela est requis, CID Digitale doit appliquer des garanties appropriées aux transferts internationaux. Les pays, sous-traitants ultérieurs et mécanismes contractuels définitifs doivent être vérifiés dans les accords et configurations de production avant la version juridique finale ; la présente politique ne présume aucun détail non confirmé.',
    ),
    _LegalSection(
      '8. Durées de conservation proposées',
      'La politique opérationnelle suivante est une proposition soumise à une révision juridique et technique finale :\n\n• compte et profil : pendant la durée du compte ; après une demande de suppression valide, suppression ou anonymisation normalement dans les 30 jours, sauf obligation légale, litige ou autre fondement justifié ;\n• véhicules et données d’assurance du profil : tant qu’ils sont nécessaires au service ou jusqu’à leur suppression, sous réserve des mêmes exceptions ;\n• dossiers CID, sinistres, photographies, documents, signatures et pièces jointes : 10 ans après la clôture du dossier ;\n• chats et communications liés à un dossier : la même durée proposée de 10 ans ;\n• rendez-vous et demandes aux ateliers sans lien avec un dossier d’assurance : 2 ans après la conclusion ou l’annulation ;\n• demandes d’assistance : 2 ans après leur clôture ;\n• journaux techniques et de sécurité : normalement 12 mois au maximum, sauf besoin de sécurité, d’enquête ou obligation légale ;\n• sauvegardes : durée maximale indicative de 90 jours, à confirmer techniquement et qui ne doit pas être comprise comme une fonctionnalité déjà vérifiée.\n\nCes durées peuvent être prolongées dans la mesure nécessaire aux obligations légales, à la constatation ou à la défense de droits et aux litiges. À leur échéance, les données sont supprimées ou anonymisées lorsque cela est techniquement et juridiquement possible.',
    ),
    _LegalSection(
      '9. Sécurité',
      'CID Digitale met en œuvre des mesures techniques et organisationnelles raisonnables et proportionnées au risque, notamment l’authentification, les contrôles d’accès, la séparation des rôles, les politiques d’accès aux données, le chiffrement des communications en transit, la minimisation et la réduction ou l’assainissement des journaux. Les accès et autorisations sont limités selon le service et le rôle.\n\nAucun système ne peut garantir une sécurité absolue. Les procédures organisationnelles, la gestion des incidents et les configurations de production doivent être réexaminées périodiquement.',
    ),
    _LegalSection(
      '10. Droits de la personne concernée',
      'Dans les limites du droit applicable, vous pouvez demander des informations sur le traitement et l’accès aux données, leur rectification, leur suppression, la limitation ou l’opposition, ainsi que leur remise ou portabilité lorsqu’elle est prévue. Vous pouvez retirer un consentement pour l’avenir sans porter atteinte à la licéité du traitement antérieur au retrait. Vous pouvez également introduire une réclamation auprès de l’autorité de protection des données compétente.\n\nCes droits ne sont pas absolus : des obligations légales, des besoins de conservation, les droits de tiers ou la constatation et la défense de droits peuvent justifier une limitation ou la conservation de certaines données.',
    ),
    _LegalSection(
      '11. Présenter une demande',
      'Écrivez à support@ciddigital.ch en précisant le droit exercé et uniquement les informations strictement nécessaires pour identifier le compte ou les données concernées. Une vérification raisonnable de l’identité peut être demandée afin de protéger les informations. CID Digitale répondra dans les délais prévus par le droit applicable. Pour les données déjà transmises à des ateliers ou assurances, il peut aussi être nécessaire de contacter ces destinataires.',
    ),
    _LegalSection(
      '12. Protection des données dès la conception et minimisation',
      'CID Digitale vise à collecter et partager uniquement les données nécessaires à la fonction choisie, à limiter les accès selon les rôles et à éviter dans les journaux les contenus personnels, jetons, payloads, coordonnées, documents OCR ou réponses complètes des services. L’utilisateur est invité à ne pas saisir d’informations excessives et à vérifier les destinataires avant toute transmission.',
    ),
    _LegalSection(
      '13. Modifications et version de la politique',
      'La présente politique peut être mise à jour lorsque le service, les fournisseurs, les traitements ou les obligations applicables évoluent. La date et la version indiquées identifient le texte en vigueur. Les modifications substantielles seront communiquées de manière appropriée et, lorsque cela est requis, une nouvelle acceptation pourra être demandée.',
    ),
  ],
);

const _privacyEn = _LegalDocumentCopy(
  title: 'Privacy Policy',
  eyebrow: 'CID Digitale · Customer Area',
  summary:
      'This policy explains how CID Digitale processes personal data in the Customer area and connected services.',
  draftTitle: 'Document undergoing final legal review',
  draftBody:
      'The text reflects the verified functions and providers. Before the final legal version, the controller’s full identity and address, the future corporate structure, the proposed retention periods, international-transfer safeguards and, where necessary, the applicable law and jurisdiction must be validated.',
  lastUpdated: 'Last updated: 8 August 2026 · Version $privacyPolicyVersion',
  sections: [
    _LegalSection(
      '1. Controller and contact details',
      'The controller is the operator of CID Digitale. The future incorporation of CID Digitale GmbH is planned; that company has not yet been incorporated and is not identified as the current controller. The full legal name, address and any Swiss commercial-register details will be added after incorporation and must be completed before the final legal version.\n\nContact for privacy matters and exercising rights: support@ciddigital.ch.',
    ),
    _LegalSection(
      '2. Data we process',
      'Depending on the features used, CID Digitale may process:\n\n• account, authentication, profile, and contact data, such as first name, last name, email, phone number, and address;\n• vehicle data, such as licence plate, characteristics, chassis number/VIN where used, and vehicle documents;\n• insurance data, such as company, policy references, and information needed to handle a case;\n• case and accident data, such as date, time, location, GPS coordinates when the feature is used, description and circumstances, participants, witnesses, any injured persons, and information entered in the CID form;\n• photographs, images, PDFs, documents, attachments, signatures where applicable, and data extracted by OCR;\n• messages and communications with workshops and insurers, appointment requests, and support requests;\n• the date, time, and version of Privacy Policy and Terms of Use acceptances;\n• technical and security data needed for operation, protection, and diagnosis, including ordinary network and request metadata where generated by providers.\n\nA case may exceptionally contain particularly sensitive information, for example references to injured persons. CID Digitale does not state that it systematically collects health data. Users must enter only relevant and necessary information.',
    ),
    _LegalSection(
      '3. Purposes of processing',
      'Data is processed to:\n\n• create and manage accounts, Customer profiles, and vehicles;\n• complete, retain, view, and transmit CID cases and accident or claim information;\n• manage photographs, documents, and PDFs and, on request, extract data from them using OCR;\n• use location, address, or geographic area for requested features such as location and workshop search;\n• transmit information to workshops and insurers involved in the workflow selected by the user;\n• handle operational communications, service emails, appointments, requests, and support;\n• maintain service security and continuity, prevent abuse, and diagnose technical issues with data limited to what is necessary;\n• comply with legal obligations and establish, exercise, or defend rights.',
    ),
    _LegalSection(
      '4. Legal bases',
      'Subject to applicable law, processing relies on performance of the requested service and pre-contractual steps; consent where required; compliance with legal obligations; and overriding legitimate or private interests, particularly security, abuse prevention, operation of the service, and legal defence, after balancing the interests concerned. Any particularly sensitive information is also subject to the additional conditions required by law.\n\nThe final mapping of each purpose to its legal basis, including whether the GDPR applies in addition to Swiss law, remains subject to final legal review.',
    ),
    _LegalSection(
      '5. Verified technical providers and processing',
      'The following verified providers or components are used to deliver the service:\n\n• Supabase: authentication, database, Storage, Edge Functions, and backend services. The Production project is configured in the West EU region (Ireland, eu-west-1). It may receive and store the categories of application data described in this policy;\n• Vercel: hosting and delivery of the web frontend, deployment infrastructure, and technical logs containing ordinary request data; it is not the service’s application database;\n• Resend: delivery of operational emails. It receives sender and recipient addresses, subject, necessary message content and, where provided by the workflow, attachments or documents and case data needed for the email;\n• Google Places: place and workshop search. It may receive search terms, coordinates or geographic area, language/locale, and ordinary technical request information;\n• OpenStreetMap/Nominatim: reverse geocoding. It receives the precise coordinates to be converted into an address. In the verified flow, name, email, licence plate, insurance data, or case identifier are not intentionally added;\n• Google ML Kit: on-device OCR text recognition on supported platforms. Images and text are processed locally. The component may make technical communications or platform model downloads, but it is not presented as a recipient of the images;\n• Google Cloud Vision: the ocr-libretto-cloud Edge Function is available in the backend, but it is not called by the verified active Customer flow. It is therefore not described as ordinary current processing; activation would require a new privacy review;\n• Tesseract.js: a technical dependency is present, but it is not used in the verified active Customer OCR flow. It is not considered a current recipient of documents.\n\nDetails that cannot be determined conclusively from the project, such as every subprocessor, provider log period, and internal configuration, must be validated against current documentation and agreements.',
    ),
    _LegalSection(
      '6. Workshops, insurers, and other recipients',
      'Data is shared only to the extent necessary with the selected or involved workshop, the competent or involved insurer, necessary technical providers and, where required by law, authorities, advisers, or other authorised parties. Transmission to a workshop or insurer depends on the user’s request and selected workflow.\n\nWorkshops and insurers may process data under their own responsibility and according to their own duties and retention periods. Deletion by CID Digitale does not automatically delete copies already transmitted to those recipients; related requests may need to be addressed directly to them.',
    ),
    _LegalSection(
      '7. Processing locations and transfers',
      'The Supabase Production database is configured in Ireland (West EU, eu-west-1). Depending on the provider, its subprocessors, and the feature used, data or technical metadata may also be processed in Switzerland, the European Economic Area, or other countries. Resend and other providers may involve international processing.\n\nWhere required, CID Digitale must apply appropriate safeguards for international transfers. The final countries, subprocessors, and contractual mechanisms must be checked against production agreements and configurations before the final legal version; this policy does not assume unconfirmed details.',
    ),
    _LegalSection(
      '8. Proposed retention periods',
      'The following operational policy is a proposal subject to final legal and technical review:\n\n• account and profile: for the life of the account; following a valid deletion request, deletion or anonymisation normally within 30 days, unless a legal duty, dispute, or other justified basis applies;\n• profile vehicle and insurance data: while needed for the service or until deletion, subject to the same exceptions;\n• CID cases, claims, photographs, documents, signatures, and attachments: 10 years after case closure;\n• case-related chats and communications: the same proposed 10-year period;\n• appointments and workshop requests not linked to an insurance case: 2 years after completion or cancellation;\n• support requests: 2 years after closure;\n• technical and security logs: normally no more than 12 months, unless required for security, investigation, or legal purposes;\n• backups: an indicative maximum of 90 days, to be technically confirmed and not to be understood as an already verified feature.\n\nPeriods may be extended to the extent necessary for legal duties, establishing or defending rights, and disputes. At expiry, data is deleted or anonymised where technically and legally possible.',
    ),
    _LegalSection(
      '9. Security',
      'CID Digitale uses reasonable technical and organisational measures proportionate to the risk, including authentication, access controls, role separation, data-access policies, encryption of communications in transit, minimisation, and reduced or sanitised logging. Access and permissions are restricted according to the service and role.\n\nNo system can guarantee absolute security. Organisational procedures, incident management, and production configurations must be reviewed periodically.',
    ),
    _LegalSection(
      '10. Your rights',
      'Subject to applicable law, you may request information about processing and access to data, correction, deletion, restriction or objection, as well as delivery or portability where available. You may withdraw consent for the future without affecting the lawfulness of processing before withdrawal. You may also lodge a complaint with the competent data protection authority.\n\nThese rights are not absolute: legal duties, retention needs, third-party rights, or the establishment and defence of claims may justify a restriction or continued retention of certain data.',
    ),
    _LegalSection(
      '11. How to submit a request',
      'Email support@ciddigital.ch, stating the right you wish to exercise and only the information strictly necessary to identify the account or relevant data. A reasonable identity check may be required to protect the information. CID Digitale will respond within the time limits set by applicable law. For data already transmitted to workshops or insurers, those recipients may also need to be contacted.',
    ),
    _LegalSection(
      '12. Privacy by design and minimisation',
      'CID Digitale aims to collect and share only the data needed for the selected feature, restrict access by role, and avoid personal content, tokens, payloads, coordinates, OCR documents, or complete service responses in logs. Users should avoid entering excessive information and verify recipients before transmission.',
    ),
    _LegalSection(
      '13. Changes and version of this Privacy Policy',
      'This policy may be updated when the service, providers, processing, or applicable obligations change. The displayed date and version identify the current text. Material changes will be communicated appropriately and, where required, renewed acceptance may be requested.',
    ),
  ],
);

const _termsIt = _LegalDocumentCopy(
  title: 'Termini d’uso',
  eyebrow: 'CID Digitale · Area Cliente',
  summary:
      'Questi Termini disciplinano l’accesso e l’uso dell’Area Cliente CID Digitale e delle funzioni collegate.',
  draftTitle: 'Documento in fase di revisione legale finale',
  draftBody:
      'Il testo riflette le funzioni verificate nel progetto. Prima della versione legale definitiva devono essere completati l’identità e l’indirizzo del gestore, i dati della futura società, la disciplina definitiva di responsabilità e cessazione, la legge applicabile, il foro competente e le eventuali disposizioni inderogabili a tutela dei consumatori.',
  lastUpdated:
      'Ultimo aggiornamento: 8 agosto 2026 · Versione $termsOfUseVersion',
  sections: [
    _LegalSection(
      '1. Ambito di applicazione e gestore',
      'I presenti Termini si applicano alle persone che si registrano, accedono o utilizzano l’Area Cliente CID Digitale e le relative funzioni. I flussi possono interagire con le aree Officina e Assicurazione; i presenti Termini non disciplinano automaticamente l’uso professionale di tali portali da parte dei rispettivi operatori, salvo espresso richiamo.\n\nIl servizio è attualmente gestito dal titolare del progetto CID Digitale, i cui dati completi devono essere inseriti prima della versione legale definitiva:\n\n[NOME O DENOMINAZIONE COMPLETA DEL GESTORE ATTUALE]\n[INDIRIZZO COMPLETO]\n\nÈ prevista la futura costituzione di CID Digitale GmbH; tale società non è ancora costituita né iscritta al Registro di commercio e non viene presentata come attuale fornitrice del servizio. Denominazione, indirizzo, sede ed eventuali dati CHE/UID o del Registro di commercio saranno inseriti soltanto quando realmente disponibili.',
    ),
    _LegalSection(
      '2. Natura e descrizione del servizio',
      'CID Digitale è una piattaforma digitale di supporto che, secondo le funzioni disponibili, consente di registrare e gestire un account, un profilo Cliente e veicoli; compilare e gestire pratiche CID o relative a sinistri; caricare fotografie, documenti e PDF; registrare, riprodurre, conservare localmente, rimuovere e condividere volontariamente note vocali sui dispositivi supportati; utilizzare funzioni OCR, QR Code, token e link dedicati; conservare localmente bozze, cache o code offline; trasmettere informazioni a officine o assicurazioni coinvolte; inviare richieste di servizi o appuntamenti; e gestire comunicazioni operative collegate.\n\nCID Digitale facilita la raccolta, l’organizzazione e lo scambio di informazioni. Non sostituisce assicurazioni, officine, autorità, periti, medici, avvocati o altri professionisti e non assume le loro decisioni o responsabilità.',
    ),
    _LegalSection(
      '3. Registrazione e account',
      'L’utente deve fornire informazioni corrette e aggiornate, utilizzare il proprio account e proteggere ragionevolmente credenziali e dispositivi di accesso. È vietato utilizzare l’account di un’altra persona o consentire accessi non autorizzati, salvo funzioni o deleghe espressamente previste dal servizio.\n\nQuando ragionevolmente possibile, l’utente deve segnalare senza ritardo a support@ciddigital.ch il sospetto uso non autorizzato o la compromissione delle credenziali. L’utente risponde delle attività a lui imputabili svolte tramite l’account, nei limiti consentiti dalla legge; ciò non esonera il gestore dai propri obblighi di sicurezza e protezione del servizio.',
    ),
    _LegalSection(
      '4. Uso corretto e divieto di abusi',
      'Il servizio deve essere utilizzato in modo lecito, corretto e coerente con le sue finalità. È vietato, in particolare:\n\n• inserire intenzionalmente informazioni false, fraudolente o ingannevoli;\n• accedere o tentare di accedere senza autorizzazione ad account, dati, sistemi o aree riservate;\n• aggirare controlli, interferire con sicurezza o funzionamento, introdurre codice dannoso o sovraccaricare il servizio;\n• abusare di account, QR Code, token, link dedicati, procedure di condivisione o sistemi di comunicazione;\n• impersonare terzi o utilizzare identità e credenziali altrui;\n• caricare o trasmettere contenuti illeciti, offensivi, dannosi, non autorizzati o lesivi dei diritti altrui;\n• utilizzare la piattaforma per finalità estranee o incompatibili con il servizio.',
    ),
    _LegalSection(
      '5. Dati, fotografie, registrazioni audio e documenti forniti dall’utente',
      'L’utente deve fornire dati pertinenti e ragionevolmente accurati e deve avere il diritto o un’altra base valida per caricare, registrare, utilizzare e trasmettere fotografie, registrazioni audio, documenti e informazioni. Particolare attenzione è richiesta per dati riguardanti altre persone coinvolte in un sinistro, testimoni, persone ferite, documenti assicurativi, registrazioni e immagini che rendono identificabili persone o beni. La sezione dedicata alle persone ferite può comprendere dati anagrafici e di contatto, data di nascita, gravità indicata, zona del corpo interessata, informazioni sui soccorsi, eventuale trasporto o struttura ospedaliera e note. Devono essere inserite soltanto le informazioni necessarie alla funzione utilizzata.\n\nL’utente è tenuto a non usare consapevolmente dati o contenuti in modo illecito e a correggere le informazioni inesatte quando ne ha la possibilità. Questa responsabilità dell’utente non trasferisce su di lui gli obblighi che la legge attribuisce al gestore, alle officine, alle assicurazioni o agli altri destinatari.',
    ),
    _LegalSection(
      '6. OCR, QR Code, link e automazioni',
      'OCR, compilazione assistita, QR Code, link dedicati e altre automazioni servono a facilitare l’inserimento, il collegamento o la trasmissione delle informazioni. I risultati automatici possono essere incompleti, interpretati in modo errato o associati al campo sbagliato. Quando l’interfaccia offre la possibilità di controllo, l’utente deve verificare e, se necessario, correggere i dati prima dell’invio.\n\nUn QR personale può contenere, in base ai campi compilati, dati anagrafici e di contatto, indirizzo, dati del veicolo, targa, VIN, chilometraggio, prima immatricolazione, dati assicurativi, numero di polizza, numero di sinistro e numero cliente. QR di pratica, token e link dedicati possono contenere identificativi tecnici o consentire il collegamento alle informazioni previste dal relativo flusso. Devono essere condivisi soltanto con i destinatari previsti e trattati con prudenza, poiché chi ne dispone potrebbe accedere alle informazioni consentite. Nessuna funzione automatica viene presentata come infallibile o sostitutiva della verifica umana.',
    ),
    _LegalSection(
      '7. Trasmissione a officine e assicurazioni',
      'La trasmissione di dati o richieste dipende dalle scelte dell’utente, dai destinatari selezionati o configurati e dalle funzioni disponibili nel relativo flusso. Prima dell’invio, l’utente deve verificare, quando possibile, destinatario, informazioni e allegati. Quando utilizza il menu di condivisione del dispositivo, l’utente sceglie volontariamente il destinatario o servizio al quale trasmettere file e informazioni, incluse eventuali note vocali.\n\nCID Digitale non garantisce che un’assicurazione accetti una pratica, riconosca una copertura o una responsabilità, disponga un pagamento o autorizzi una riparazione. Non garantisce inoltre che un’officina accetti un incarico, esegua una prestazione, mantenga una determinata disponibilità o risponda entro un termine specifico. Le decisioni e prestazioni di tali soggetti restano di loro competenza.',
    ),
    _LegalSection(
      '8. Appuntamenti e richieste alle officine',
      'L’invio tramite CID Digitale di una preferenza di data, di una richiesta di appuntamento o di servizio costituisce normalmente una richiesta in attesa di gestione. Non equivale a una conferma definitiva, salvo che il relativo flusso mostri espressamente uno stato di conferma o venga ricevuta una comunicazione inequivoca dell’officina.\n\nDisponibilità, orario, durata, prezzo, veicolo sostitutivo e condizioni della prestazione devono essere confermati con l’officina quando pertinenti. L’utente deve verificare lo stato della richiesta e contattare l’officina in caso di urgenza o mancata conferma.',
    ),
    _LegalSection(
      '9. Servizi e fornitori terzi',
      'Il funzionamento della piattaforma dipende anche da servizi tecnici esterni verificati, tra cui Supabase per autenticazione, database, Storage ed Edge Functions; Vercel per il frontend web; Resend per e-mail operative; Google Places per la ricerca di luoghi e officine; OpenStreetMap/Nominatim per la geocodifica inversa; Google Maps quando l’utente apre il relativo collegamento esterno; Google ML Kit per OCR sul dispositivo nelle piattaforme supportate; e jsDelivr per il caricamento della dipendenza web Tesseract.js. Tesseract.js non risulta utilizzato dal flusso OCR Cliente attivo e non viene presentato come destinatario corrente dei documenti; il CDN può comunque ricevere i normali dati tecnici della richiesta HTTP. Google Cloud Vision è predisposto in un componente backend, ma non risulta utilizzato nel flusso Cliente attivo verificato e non viene presentato come funzione ordinaria corrente.\n\nDisponibilità e caratteristiche dei servizi terzi possono cambiare o subire interruzioni. Il loro utilizzo non attribuisce a CID Digitale le decisioni autonome di officine, assicurazioni o altri terzi. Per le informazioni sul trattamento dei dati si applica la Privacy Policy, che resta un documento separato.',
    ),
    _LegalSection(
      '10. Disponibilità e modifiche del servizio',
      'Il gestore presta ragionevole cura nel funzionamento della piattaforma, ma il servizio può essere temporaneamente limitato o indisponibile per manutenzione, aggiornamenti, problemi tecnici, connettività, incidenti di sicurezza, indisponibilità di fornitori esterni o eventi fuori dal suo ragionevole controllo. Ove possibile e proporzionato, vengono adottate misure per ripristinare il servizio e limitare gli effetti dell’interruzione.\n\nFunzioni possono essere corrette, aggiornate, sostituite o limitate per sicurezza, conformità, compatibilità tecnica o evoluzione del servizio. Le modifiche sostanziali che incidono sui diritti degli utenti saranno gestite secondo la sezione dedicata alle modifiche dei Termini.',
    ),
    _LegalSection(
      '11. Garanzie e affidamento sulle informazioni',
      'CID Digitale è uno strumento di supporto e non promette risultati assicurativi, legali, tecnici o commerciali specifici. Nei limiti consentiti dalla legge, non sono garantiti funzionamento ininterrotto, assenza assoluta di errori, compatibilità con ogni dispositivo o correttezza di informazioni provenienti da utenti o terzi.\n\nRisultati OCR, mappe, geocodifica, ricerche di officine, disponibilità, comunicazioni automatiche e altri dati assistiti devono essere verificati quando rilevanti. Restano pienamente applicabili le garanzie e i diritti inderogabili previsti dalla legge.',
    ),
    _LegalSection(
      '12. Responsabilità',
      'Il gestore risponde secondo la legge applicabile dei danni diretti dimostrati e a lui imputabili derivanti da una violazione dei propri obblighi. Nel valutare la responsabilità devono essere distinti il funzionamento della piattaforma, i dati inseriti o confermati dagli utenti, le decisioni e attività di officine e assicurazioni, i servizi di altri terzi e gli eventi tecnici fuori dal ragionevole controllo del gestore.\n\nNei limiti consentiti dalla legge, il gestore non risponde di conseguenze causate prevalentemente da informazioni false o inesatte fornite dall’utente, uso non autorizzato imputabile all’utente, decisioni autonome di assicurazioni o officine, mancato rispetto di scadenze esterne non gestite dalla piattaforma o indisponibilità di terzi non ragionevolmente controllabile. Eventuali esclusioni per danni indiretti o conseguenti si applicano soltanto nella misura consentita dalla legge.\n\nNulla nei presenti Termini esclude o limita responsabilità inderogabili, in particolare quelle che non possono essere escluse per dolo o colpa grave. La formulazione definitiva e l’eventuale limite economico devono essere verificati legalmente.',
    ),
    _LegalSection(
      '13. Proprietà intellettuale e contenuti dell’utente',
      'Software, struttura, grafica, nome e segni distintivi CID Digitale, testi originali e altri elementi della piattaforma appartengono ai rispettivi titolari e sono protetti nei limiti della legge applicabile. L’uso del servizio non trasferisce all’utente diritti di proprietà intellettuale su tali elementi. Non è consentito copiarli, modificarli, distribuirli o sfruttarli oltre quanto permesso dalla legge o da un’autorizzazione.\n\nL’utente conserva i diritti sui propri dati, fotografie, registrazioni audio, documenti e contenuti. Egli concede al gestore esclusivamente i diritti tecnici non esclusivi necessari per ospitarli, conservarli, elaborarli, convertirli e trasmetterli nell’ambito delle funzioni richieste e secondo i criteri di conservazione descritti nella Privacy Policy e previsti dalla legge. Tale autorizzazione non permette un utilizzo estraneo all’erogazione, sicurezza o tutela legale del servizio.',
    ),
    _LegalSection(
      '14. Limitazione o sospensione dell’account',
      'L’accesso può essere temporaneamente limitato o sospeso quando ciò è ragionevolmente necessario per fronteggiare un rischio di sicurezza, un abuso, una violazione grave o ripetuta dei presenti Termini, un obbligo legale o un pericolo concreto per utenti, terzi o piattaforma. La misura deve essere proporzionata alla gravità e all’urgenza della situazione.\n\nQuando le circostanze lo consentono, l’utente viene informato del motivo e della possibilità di rimediare o chiedere chiarimenti. Un intervento immediato può essere necessario se il preavviso comprometterebbe sicurezza, indagini, obblighi legali o diritti di terzi. La sospensione non elimina gli eventuali diritti dell’utente previsti dalla legge.',
    ),
    _LegalSection(
      '15. Cancellazione dell’account e cessazione del servizio',
      'L’utente può chiedere la chiusura dell’account scrivendo a support@ciddigital.ch. La chiusura impedisce o limita l’uso futuro del servizio, ma non comporta necessariamente la cancellazione immediata di ogni dato, delle copie già trasmesse a officine o assicurazioni o delle copie locali presenti sul dispositivo o nel browser. Il logout e la cancellazione dei dati dai sistemi remoti non eliminano necessariamente cache, bozze, code offline, immagini, profili QR, veicoli o file audio conservati localmente. L’utente deve utilizzare le funzioni di eliminazione disponibili e, quando necessario, rimuovere i dati dell’applicazione o del sito dal proprio dispositivo. Conservazione, cancellazione e anonimizzazione seguono la Privacy Policy, gli obblighi legali, le controversie pendenti e gli altri motivi legittimi applicabili.\n\nIl gestore può cessare il servizio o singole funzioni per motivate ragioni legali, tecniche, di sicurezza o organizzative. Quando ragionevolmente possibile, le modifiche rilevanti vengono comunicate con preavviso adeguato e viene valutata la possibilità di consentire l’accesso o l’esportazione dei dati nei limiti tecnici e legali. La disciplina definitiva della cessazione resta soggetta a revisione legale.',
    ),
    _LegalSection(
      '16. Protezione dei dati personali',
      'Il trattamento dei dati personali, i destinatari, i fornitori tecnici, i trasferimenti, i criteri di conservazione ancora da approvare e verificare e i diritti degli interessati sono descritti nella Privacy Policy, consultabile separatamente durante la registrazione e dall’Area Cliente. Privacy Policy e Termini d’uso sono documenti distinti. In caso di richiesta di cancellazione o esercizio di diritti si applicano le condizioni e le eventuali limitazioni indicate nella Privacy Policy e nella legge.',
    ),
    _LegalSection(
      '17. Modifiche ai Termini',
      'I Termini possono essere aggiornati per riflettere modifiche del servizio, dei flussi, dei fornitori, dei requisiti di sicurezza o degli obblighi applicabili. Data e versione identificano il testo vigente. Le modifiche sostanziali saranno comunicate in modo adeguato e, quando richiesto dalla legge o dalla natura della modifica, potrà essere richiesta una nuova accettazione prima di proseguire l’uso del servizio.',
    ),
    _LegalSection(
      '18. Legge applicabile e foro',
      'CLAUSOLA PROVVISORIA SOGGETTA A REVISIONE LEGALE FINALE: la legge applicabile e il foro competente non possono essere definiti in modo definitivo prima del completamento dell’identità, della sede e dei dati del gestore e della futura società. La clausola finale dovrà considerare il diritto svizzero applicabile, le norme imperative, la protezione dei consumatori e gli eventuali fori inderogabili, senza limitare diritti che la legge riconosce all’utente.',
    ),
    _LegalSection(
      '19. Contatti',
      'Per domande sui presenti Termini, segnalazioni relative all’account o richieste riguardanti il servizio: support@ciddigital.ch. I dati legali e postali completi del gestore saranno inseriti prima della versione legale definitiva.',
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
