import 'dart:async';
import 'dart:typed_data';
import 'dart:io' show File, Platform;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'ocr_utils.dart';

class ScannerLibrettoPage extends StatefulWidget {
  final String quale;

  const ScannerLibrettoPage({super.key, required this.quale});

  @override
  State<ScannerLibrettoPage> createState() => _ScannerLibrettoPageState();
}

class _ScannerLibrettoPageState extends State<ScannerLibrettoPage> {
  CameraController? _controller;
  bool _initializing = true;
  bool _capturing = false;
  bool _processingFrame = false;
  final List<String> _targaHistory = [];
  static const int _targaWindow = 5;
  final ImagePicker _picker = ImagePicker();
  Timer? _scanTimer;
  String _status = 'Inquadra il libretto e tieni fermo.';
  int _frameCount = 0;
  String? _bestTarga;
  String? _bestNome;
  String? _bestAssicurazione;
  String? _bestIndirizzo;
  String? _bestCapCitta;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() {
          _status = 'Nessuna fotocamera disponibile.';
          _initializing = false;
        });
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      await _controller!.initialize();
      if (!mounted) return;
      _startScanLoop();
      setState(() => _initializing = false);
    } catch (_) {
      _scanTimer?.cancel();
      await _controller?.dispose();
      _controller = null;
      if (mounted) {
        setState(() {
          _status = 'Errore inizializzazione fotocamera.';
          _initializing = false;
        });
      }
    }
  }

  void _startScanLoop() {
    _scanTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted ||
          _capturing ||
          _controller == null ||
          !_controller!.value.isInitialized) return;
      _capturing = true;
      try {
        final file = await _controller!.takePicture();
        await _processImage(file.path);
      } catch (_) {
        if (mounted) {
          setState(() {
            _status = 'Errore nello scatto automatico.';
          });
        }
      } finally {
        _capturing = false;
      }
    });
  }

  Future<void> _processImage(String path) async {
    if (_processingFrame) return;
    if (path.isEmpty) return;
    final fileOnDisk = File(path);
    if (!await fileOnDisk.exists()) return;

    _processingFrame = true;
    try {
      final input = InputImage.fromFilePath(path);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final result = await recognizer.processImage(input);
      await recognizer.close();

      debugPrint('OCR fullText: ${result.text}');
      debugPrint('OCR blocks: ${result.blocks.map((b) => b.text).toList()}');

      final blocks = result.blocks.map((b) => b.text).toList();
      final targa = estraiTargaDaTesto(result.text) ??
          blocks
              .map((b) => estraiTargaDaTesto(b))
              .firstWhere((e) => e != null, orElse: () => null);
      final extra = estraiNomeAssicurazioneIndirizzoDaTesto(
        result.text,
        blocchi: blocks,
      );
      final capCitta = extra['capCitta'];

      _frameCount++;
      if (targa != null) _registerTargaCandidate(targa);
      if (extra['nome'] != null) _bestNome = extra['nome'];
      if (extra['assicurazione'] != null)
        _bestAssicurazione = extra['assicurazione'];
      if (extra['indirizzo'] != null) _bestIndirizzo = extra['indirizzo'];
      // capCitta non influisce sull'autoscatto, ma la salviamo per il riepilogo
      if (capCitta != null) _bestCapCitta = capCitta;

      final complete = _bestTarga != null &&
          (_bestNome != null || _bestAssicurazione != null);

      if (complete) {
        await _finishAndReturn(path);
        return;
      }

      if (mounted) {
        setState(() {
          _status = 'Scansione... '
              '${_bestTarga != null ? 'Targa ok. ' : ''}'
              '${_bestNome != null ? 'Nome ok. ' : ''}'
              '${_bestAssicurazione != null ? 'Assicurazione ok. ' : ''}'
              'Frame: $_frameCount';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = 'Errore nella lettura dell\'immagine.';
        });
      }
    } finally {
      _processingFrame = false;
    }
  }

  Future<void> _finishAndReturn(String path) async {
    _scanTimer?.cancel();
    await _controller?.dispose();
    _controller = null;
    if (!mounted) return;
    Navigator.of(context).pop(
      OcrLibrettoResult(
        path: path,
        targa: _bestTarga,
        nome: _bestNome,
        assicurazione: _bestAssicurazione,
        indirizzo: _bestIndirizzo,
        capCitta: _bestCapCitta,
      ),
    );
  }

  Future<void> _takePictureManually() async {
    if (_capturing || _initializing) return;
    _capturing = true;
    try {
      if (_controller != null && _controller!.value.isInitialized) {
        final file = await _controller!.takePicture();
        await _processImage(file.path);
      } else {
        final picked = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
        if (picked != null) {
          await _processImage(picked.path);
        } else if (mounted) {
          setState(() {
            _status = 'Scatto annullato.';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = 'Errore nello scatto.';
        });
      }
    } finally {
      _capturing = false;
    }
  }

  void _registerTargaCandidate(String value) {
    final compact = value.replaceAll(' ', '').toUpperCase();
    if (compact.isEmpty) return;
    _targaHistory.add(compact);
    if (_targaHistory.length > _targaWindow) {
      _targaHistory.removeAt(0);
    }
    final counts = <String, int>{};
    for (final t in _targaHistory) {
      counts[t] = (counts[t] ?? 0) + 1;
    }
    final best = counts.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    // Richiede almeno 2 occorrenze per evitare falsi positivi.
    if (best.value >= 2 || _targaHistory.length == _targaWindow) {
      final normalized = best.key.length == 7
          ? '${best.key.substring(0, 2)} ${best.key.substring(2, 5)} ${best.key.substring(5)}'
          : best.key;
      _bestTarga = normalized;
    }
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return WebUploadLibrettoPage(quale: widget.quale);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Scanner libretto ${widget.quale}'),
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                if (_controller != null && _controller!.value.isInitialized)
                  CameraPreview(_controller!),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.black54,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _status,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Suggerimenti: luce buona, tieni fermo, inquadra il libretto intero.',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    _capturing ? null : _takePictureManually,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white70),
                                ),
                                child: const Text('Scatta ora'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  _scanTimer?.cancel();
                                  await _controller?.dispose();
                                  _controller = null;
                                  if (mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                                child: const Text('Annulla'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class WebUploadLibrettoPage extends StatefulWidget {
  final String quale;

  const WebUploadLibrettoPage({super.key, required this.quale});

  @override
  State<WebUploadLibrettoPage> createState() => _WebUploadLibrettoPageState();
}

class _WebUploadLibrettoPageState extends State<WebUploadLibrettoPage> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _bytes;
  String? _fileName;
  bool _loading = false;

  Future<void> _pickImage() async {
    setState(() => _loading = true);
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (!mounted) return;
        setState(() {
          _bytes = bytes;
          _fileName = picked.name;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Errore durante la selezione della foto.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _confirm() {
    if (_bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona una foto')),
      );
      return;
    }
    Navigator.of(context).pop({
      'kind': 'libretto_photo',
      'filename':
          _fileName ?? 'libretto_${DateTime.now().millisecondsSinceEpoch}.jpg',
      'bytes': _bytes!,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carica foto libretto'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Carica foto libretto (JPG/PNG)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 260,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _bytes == null
                    ? const Center(child: Text('Nessuna immagine selezionata'))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _bytes!,
                          fit: BoxFit.contain,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loading ? null : _pickImage,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_camera_back_outlined),
              label: const Text('Scegli/Scatta foto'),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annulla'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _confirm,
                    child: const Text('Conferma'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
