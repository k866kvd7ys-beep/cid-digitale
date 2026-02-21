import 'package:flutter/material.dart';

import 'ocr_utils.dart';

class OcrReviewPage extends StatefulWidget {
  final OcrLibrettoResult initial;

  const OcrReviewPage({super.key, required this.initial});

  @override
  State<OcrReviewPage> createState() => _OcrReviewPageState();
}

class _OcrReviewPageState extends State<OcrReviewPage> {
  late final TextEditingController _targa;
  late final TextEditingController _nome;
  late final TextEditingController _assicurazione;
  late final TextEditingController _indirizzo;
  late final TextEditingController _capCitta;

  @override
  void initState() {
    super.initState();
    _targa = TextEditingController(text: widget.initial.targa ?? '');
    _nome = TextEditingController(text: widget.initial.nome ?? '');
    _assicurazione =
        TextEditingController(text: widget.initial.assicurazione ?? '');
    _indirizzo = TextEditingController(text: widget.initial.indirizzo ?? '');
    _capCitta = TextEditingController(text: widget.initial.capCitta ?? '');
  }

  @override
  void dispose() {
    _targa.dispose();
    _nome.dispose();
    _assicurazione.dispose();
    _indirizzo.dispose();
    _capCitta.dispose();
    super.dispose();
  }

  void _conferma() {
    Navigator.of(context).pop(
      OcrLibrettoResult(
        path: widget.initial.path,
        targa: _targa.text.trim().isEmpty ? null : _targa.text.trim(),
        nome: _nome.text.trim().isEmpty ? null : _nome.text.trim(),
        assicurazione: _assicurazione.text.trim().isEmpty
            ? null
            : _assicurazione.text.trim(),
        indirizzo:
            _indirizzo.text.trim().isEmpty ? null : _indirizzo.text.trim(),
        capCitta: _capCitta.text.trim().isEmpty ? null : _capCitta.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conferma dati OCR')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _targa,
              decoration: const InputDecoration(labelText: 'Targa'),
            ),
            TextField(
              controller: _nome,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            TextField(
              controller: _assicurazione,
              decoration: const InputDecoration(labelText: 'Assicurazione'),
            ),
            TextField(
              controller: _indirizzo,
              decoration: const InputDecoration(labelText: 'Indirizzo'),
            ),
            TextField(
              controller: _capCitta,
              decoration: const InputDecoration(labelText: 'CAP + città'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _conferma,
              child: const Text('Conferma dati'),
            ),
          ],
        ),
      ),
    );
  }
}
