import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/supabase_config.dart';
import '../qr/qr_parser.dart';
import '../services/supabase_service.dart';

class SupabaseDemoScreen extends StatefulWidget {
  const SupabaseDemoScreen({super.key});

  @override
  State<SupabaseDemoScreen> createState() => _SupabaseDemoScreenState();
}

class _SupabaseDemoScreenState extends State<SupabaseDemoScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final JsonEncoder _prettyEncoder = const JsonEncoder.withIndent('  ');
  final TextEditingController _qrInputController = TextEditingController();

  String? _claimId;
  Map<String, dynamic>? _claimDetail;
  List<Map<String, dynamic>> _claims = [];
  String? _qrToken;
  String? _qrUrl;

  bool _busy = false;
  bool _loadingList = false;
  bool _loadingDetail = false;
  bool _importing = false;

  bool get _hasPlaceholderConfig =>
      supabaseUrl.startsWith('INCOLLA_') ||
      supabaseAnonKey.startsWith('INCOLLA_');

  @override
  void initState() {
    super.initState();
    if (!_hasPlaceholderConfig) {
      _loadClaimsList();
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _loadClaimsList() async {
    if (_hasPlaceholderConfig) {
      _showSnack('Inserisci URL e ANON KEY in SupabaseConfig');
      return;
    }
    setState(() {
      _loadingList = true;
    });
    try {
      final items = await _supabaseService.listRecentClaims();
      if (!mounted) return;
      setState(() {
        _claims = items;
      });
    } catch (e) {
      _showSnack('Errore caricamento lista: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingList = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _loadClaimDetail(String claimId) async {
    if (_hasPlaceholderConfig) {
      _showSnack('Inserisci URL e ANON KEY in SupabaseConfig');
      return null;
    }
    setState(() {
      _loadingDetail = true;
    });
    try {
      final detail = await _supabaseService.getClaim(claimId);
      if (!mounted) return detail;
      setState(() {
        _claimDetail = detail;
      });
      return detail;
    } catch (e) {
      _showSnack('Errore caricamento dettaglio: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingDetail = false;
        });
      }
    }
    return null;
  }

  Map<String, dynamic> _buildFakePayload() {
    return {
      'title': 'CID demo',
      'created_at': DateTime.now().toIso8601String(),
      'note': 'Payload di test generato dall\'app',
    };
  }

  Future<void> _createClaim() async {
    if (_hasPlaceholderConfig) {
      _showSnack('Inserisci URL e ANON KEY in SupabaseConfig');
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
    });
    try {
      final payload = _buildFakePayload();
      final newId = await _supabaseService.rpcCreateClaimDraft(
        workshopCode: 'DEMO001',
        payload: payload,
      );
      if (newId.isEmpty) {
        throw Exception('Claim ID mancante dalla risposta RPC');
      }
      if (!mounted) return;
      setState(() {
        _claimId = newId;
        _qrToken = null;
        _qrUrl = null;
      });
      await _loadClaimDetail(newId);
      await _loadClaimsList();
      _showSnack('Pratica creata su Supabase.');
    } catch (e) {
      _showSnack('Errore creazione pratica: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _generateWorkshopQr() async {
    if (_hasPlaceholderConfig) {
      _showSnack('Inserisci URL e ANON KEY in SupabaseConfig');
      return;
    }
    final id = _claimId;
    if (id == null) {
      _showSnack('Crea prima una pratica.');
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final token =
          await _supabaseService.rpcCreateClaimLinkWorkshop(claimId: id);
      if (!mounted) return;
      setState(() {
        _qrToken = token;
        _qrUrl = '$officinaWebBaseUrl?token=$token';
      });
      await _loadClaimDetail(id);
      await _loadClaimsList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openQrInBrowser() async {
    final url = _qrUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showSnack('URL QR non valido.');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      _showSnack('Impossibile aprire il browser.');
    }
  }

  Future<void> _openClaim(Map<String, dynamic> claim) async {
    if (_hasPlaceholderConfig) {
      _showSnack('Inserisci URL e ANON KEY in SupabaseConfig');
      return;
    }
    final id = '${claim['id']}';
    setState(() {
      _claimId = id;
      _qrToken = null;
      _qrUrl = null;
    });
    final detail = await _loadClaimDetail(id);
    if (!mounted || detail == null) return;
    final payload = detail['payload_json'];
    final pretty = _prettyPayload(payload);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Text(
              pretty,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _importFromQrPayload() async {
    if (_hasPlaceholderConfig) {
      _showSnack('Inserisci URL e ANON KEY in SupabaseConfig');
      return;
    }

    final raw = _qrInputController.text.trim();
    if (raw.isEmpty) {
      _showSnack('Incolla il contenuto del QR o l\'URL con token.');
      return;
    }

    setState(() {
      _importing = true;
      _loadingDetail = true;
    });

    try {
      final parsed = parseQr(raw);

      if (parsed.token != null && parsed.token!.isNotEmpty) {
        final claim = await _supabaseService.fetchClaimByToken(parsed.token!);

        if (!mounted) return;
        setState(() {
          _claimId = claim['id']?.toString();
          _qrToken = parsed.token;
          _qrUrl = '$officinaWebBaseUrl?token=${parsed.token}';
          _claimDetail = claim;
        });

        await _loadClaimsList();
        _showSnack('Pratica importata tramite token.');
        return;
      }

      if (parsed.legacyClaimId != null && parsed.legacyClaimId!.isNotEmpty) {
        _showSnack(
          'QR legacy non supportato: rigenera il QR (serve token in claim_links).',
        );
        return;
      }

      _showSnack('QR non riconosciuto.');
    } catch (e, _) {
      debugPrint('QR import error: ${e.toString()}');
      if (mounted) {
        _showSnack('Errore import QR: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
          _loadingDetail = false;
        });
      }
    }
  }

  String _formatIsoDate(dynamic value) {
    if (value is String) {
      final dt = DateTime.tryParse(value);
      if (dt != null) {
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return value;
    }
    return '';
  }

  String _prettyPayload(dynamic payload) {
    if (payload == null) return 'payload_json vuoto';
    try {
      return _prettyEncoder.convert(payload);
    } catch (_) {
      return '$payload';
    }
  }

  @override
  void dispose() {
    _qrInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CID Digitale • Supabase'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_hasPlaceholderConfig)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Inserisci URL e ANON KEY in SupabaseConfig per usare questa demo.',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '1) Crea pratica (draft)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _busy ? null : _createClaim,
                        icon: _busy
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add),
                        label: const Text('Crea pratica (draft)'),
                      ),
                      if (_claimId != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Ultima pratica: $_claimId',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: _busy
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.qr_code),
                        label: const Text('Genera QR Officina'),
                        onPressed: (_claimId == null || _busy)
                            ? null
                            : _generateWorkshopQr,
                      ),
                      if (_qrUrl != null && _qrToken != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'QR Officina (token-based)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        QrImageView(
                          data: _qrUrl!,
                          size: 220,
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          _qrUrl!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _qrUrl == null ? null : _openQrInBrowser,
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Apri in browser'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '2) Importa pratica da QR/token',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _qrInputController,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Payload QR o URL con token',
                          hintText:
                              'https://...token=XYZ oppure {"token":"XYZ"}',
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _importing ? null : _importFromQrPayload,
                        icon: _importing
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.qr_code_scanner),
                        label: const Text('Importa da QR'),
                      ),
                    ],
                  ),
                ),
              ),
              if (_claimDetail != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dettaglio pratica',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _prettyPayload(_claimDetail!['payload_json']),
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '3) Lista pratiche recenti',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            onPressed: _loadingList ? null : _loadClaimsList,
                            icon: _loadingList
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_claims.isEmpty)
                        const Text(
                          'Nessuna pratica trovata.',
                          style: TextStyle(color: Colors.black54),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _claims.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final claim = _claims[index];
                            final status = claim['status'] ?? '-';
                            final createdAt = _formatIsoDate(
                              claim['created_at'],
                            );
                            return ListTile(
                              title: Text('ID: ${claim['id']}'),
                              subtitle: Text(
                                'Status: $status\nCreato: $createdAt',
                              ),
                              onTap: () => _openClaim(claim),
                              trailing: const Icon(Icons.chevron_right),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              if (_loadingDetail) ...[
                const SizedBox(height: 8),
                const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
