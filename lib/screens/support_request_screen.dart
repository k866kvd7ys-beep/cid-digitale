import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../models/customer_profile.dart';
import '../services/customer_auth_service.dart';
import '../services/support_request_service.dart';

typedef SupportImagePicker = Future<XFile?> Function(ImageSource source);

@visibleForTesting
class SupportAttachmentCollection {
  SupportAttachmentCollection([
    Iterable<SupportRequestAttachment> initialAttachments = const [],
  ]) : _attachments = List.of(initialAttachments) {
    if (_attachments.length > maxAttachments) {
      throw ArgumentError('At most $maxAttachments attachments are supported.');
    }
  }

  static const int maxAttachments = 3;
  static const int maxBytesPerAttachment = 5 * 1024 * 1024;

  final List<SupportRequestAttachment> _attachments;

  List<SupportRequestAttachment> get attachments => List.unmodifiable(
        _attachments,
      );

  bool get canAdd => _attachments.length < maxAttachments;

  bool add(SupportRequestAttachment attachment) {
    if (!canAdd || attachment.byteSize > maxBytesPerAttachment) return false;
    _attachments.add(attachment);
    return true;
  }

  SupportRequestAttachment removeAt(int index) => _attachments.removeAt(index);
}

class SupportRequestScreen extends StatefulWidget {
  const SupportRequestScreen({
    super.key,
    required this.account,
    required this.profile,
    this.gateway,
    this.pickImage,
  });

  final CustomerAccount account;
  final CustomerProfile profile;
  final SupportRequestGateway? gateway;
  final SupportImagePicker? pickImage;

  @override
  State<SupportRequestScreen> createState() => _SupportRequestScreenState();
}

class _SupportRequestScreenState extends State<SupportRequestScreen> {
  static const Color _background = Color(0xFFF8FAFC);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  late final TextEditingController _emailController;
  late final SupportRequestGateway _gateway;
  late final SupportImagePicker _pickImage;
  final _attachments = SupportAttachmentCollection();

  SupportRequestType? _requestType;
  bool _submitting = false;
  bool _pickingAttachment = false;
  String? _pendingRequestId;
  String? _submissionError;
  SupportRequestSubmission? _submission;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? SupabaseSupportRequestGateway();
    final picker = ImagePicker();
    _pickImage = widget.pickImage ??
        (source) => picker.pickImage(source: source, imageQuality: 92);
    _emailController = TextEditingController(text: widget.account.email);
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String _requestTypeLabel(SupportRequestType type) {
    switch (type) {
      case SupportRequestType.problem:
        return _l10n.supportRequestProblem;
      case SupportRequestType.question:
        return _l10n.supportRequestQuestion;
      case SupportRequestType.suggestion:
        return _l10n.supportRequestSuggestion;
    }
  }

  String? _requiredLengthValidator(
    String? value, {
    required int minimum,
    required int maximum,
  }) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return _l10n.supportValidationRequired;
    if (normalized.length < minimum) {
      return _l10n.supportValidationMinimum(minimum);
    }
    if (normalized.length > maximum) {
      return _l10n.supportValidationMaximum(maximum);
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return _l10n.supportValidationRequired;
    final valid = RegExp(
      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
      caseSensitive: false,
    ).hasMatch(normalized);
    return valid ? null : _l10n.supportInvalidEmail;
  }

  bool _isSupportedImage(String fileName, String? mimeType) {
    final lowerName = fileName.toLowerCase();
    final extensionSupported = lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.webp');
    final normalizedMime = mimeType?.toLowerCase().trim() ?? '';
    final mimeSupported = normalizedMime.isEmpty ||
        const {
          'image/jpeg',
          'image/png',
          'image/webp',
        }.contains(normalizedMime);
    return extensionSupported && mimeSupported;
  }

  String _mimeType(String fileName, String? sourceMimeType) {
    final normalized = sourceMimeType?.toLowerCase().trim() ?? '';
    if (normalized == 'image/jpeg' ||
        normalized == 'image/png' ||
        normalized == 'image/webp') {
      return normalized;
    }
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.png')) return 'image/png';
    if (lowerName.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickAttachment(ImageSource source) async {
    if (_submitting || _pendingRequestId != null) return;
    if (!_attachments.canAdd) {
      _showMessage(_l10n.supportAttachmentLimit);
      return;
    }
    setState(() => _pickingAttachment = true);
    try {
      final file = await _pickImage(source);
      if (file == null) return;
      final fileName = file.name.trim().isEmpty ? 'support.jpg' : file.name;
      if (!_isSupportedImage(fileName, file.mimeType)) {
        _showMessage(_l10n.supportAttachmentUnsupported);
        return;
      }
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes >
          SupportAttachmentCollection.maxBytesPerAttachment) {
        _showMessage(_l10n.supportAttachmentTooLarge);
        return;
      }
      final added = _attachments.add(
        SupportRequestAttachment(
          fileName: fileName,
          mimeType: _mimeType(fileName, file.mimeType),
          bytes: Uint8List.fromList(bytes),
        ),
      );
      if (!added) {
        _showMessage(_l10n.supportAttachmentLimit);
        return;
      }
      if (mounted) setState(() {});
    } catch (_) {
      _showMessage(_l10n.supportAttachmentReadError);
    } finally {
      if (mounted) setState(() => _pickingAttachment = false);
    }
  }

  Future<void> _chooseAttachmentSource() async {
    if (_submitting || _pendingRequestId != null) return;
    if (!_attachments.canAdd) {
      _showMessage(_l10n.supportAttachmentLimit);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(_l10n.supportTakePhoto),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_pickAttachment(ImageSource.camera));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(_l10n.supportChooseGallery),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_pickAttachment(ImageSource.gallery));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submissionError = null;
    });

    if (_pendingRequestId == null && !_formKey.currentState!.validate()) {
      return;
    }
    if (_pendingRequestId == null && _requestType == null) {
      setState(() {});
      return;
    }

    setState(() => _submitting = true);
    try {
      final pendingRequestId = _pendingRequestId;
      final result = pendingRequestId == null
          ? await _gateway.submit(
              userId: widget.account.id,
              draft: SupportRequestDraft(
                requestType: _requestType!,
                subject: _subjectController.text,
                message: _messageController.text,
                replyEmail: _emailController.text,
                attachments: _attachments.attachments,
              ),
            )
          : await _gateway.retryNotification(
              userId: widget.account.id,
              requestId: pendingRequestId,
            );
      if (!mounted) return;
      setState(() => _submission = result);
    } on SupportRequestSubmissionException catch (error) {
      if (!mounted) return;
      setState(() {
        _pendingRequestId = error.savedRequestId ?? _pendingRequestId;
        _submissionError = _l10n.supportSubmissionError;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _submissionError = _l10n.supportSubmissionError);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _surface({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _border),
      ),
    );
  }

  Widget _attachmentPreview(SupportRequestAttachment attachment, int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 1,
            child: Image.memory(
              attachment.bytes,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Color(0xFFF1F5F9),
                child: Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: IconButton(
              key: Key('support-remove-attachment-$index'),
              visualDensity: VisualDensity.compact,
              tooltip: _l10n.supportRemoveAttachment,
              onPressed: _submitting || _pendingRequestId != null
                  ? null
                  : () => setState(() => _attachments.removeAt(index)),
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    final fieldsLocked = _pendingRequestId != null;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _l10n.supportHowCanWeHelp,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: _textDark,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _l10n.supportIntroDescription,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: _textMuted,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 22),
          _surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<SupportRequestType>(
                  key: const Key('support-request-type'),
                  initialValue: _requestType,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    label: _l10n.supportRequestType,
                    icon: Icons.category_outlined,
                  ),
                  items: SupportRequestType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(_requestTypeLabel(type)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: fieldsLocked
                      ? null
                      : (value) => setState(() => _requestType = value),
                  validator: (value) =>
                      value == null ? _l10n.supportValidationRequired : null,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  key: const Key('support-subject'),
                  controller: _subjectController,
                  enabled: !fieldsLocked,
                  maxLength: 120,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    label: _l10n.supportSubject,
                    icon: Icons.subject_rounded,
                  ),
                  validator: (value) => _requiredLengthValidator(
                    value,
                    minimum: 3,
                    maximum: 120,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('support-message'),
                  controller: _messageController,
                  enabled: !fieldsLocked,
                  minLines: 5,
                  maxLines: 9,
                  maxLength: 2000,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: _inputDecoration(
                    label: _l10n.supportDescription,
                    icon: Icons.notes_rounded,
                  ),
                  validator: (value) => _requiredLengthValidator(
                    value,
                    minimum: 10,
                    maximum: 2000,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('support-reply-email'),
                  controller: _emailController,
                  enabled: !fieldsLocked,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  decoration: _inputDecoration(
                    label: _l10n.supportReplyEmail,
                    icon: Icons.alternate_email_rounded,
                  ),
                  validator: _emailValidator,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _l10n.supportAttachmentsOptional,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: _textDark,
                                ),
                      ),
                    ),
                    Text(
                      '${_attachments.attachments.length}/'
                      '${SupportAttachmentCollection.maxAttachments}',
                      style: const TextStyle(
                        color: _textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _l10n.supportAttachmentRules,
                  style: const TextStyle(color: _textMuted, height: 1.4),
                ),
                if (_attachments.attachments.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 520 ? 3 : 2;
                      const spacing = 10.0;
                      final width =
                          (constraints.maxWidth - spacing * (columns - 1)) /
                              columns;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (var index = 0;
                              index < _attachments.attachments.length;
                              index++)
                            SizedBox(
                              width: width,
                              child: _attachmentPreview(
                                _attachments.attachments[index],
                                index,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  key: const Key('support-add-attachment'),
                  onPressed: fieldsLocked ||
                          _submitting ||
                          _pickingAttachment ||
                          !_attachments.canAdd
                      ? null
                      : _chooseAttachmentSource,
                  icon: _pickingAttachment
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(_l10n.supportAttachScreenshot),
                ),
              ],
            ),
          ),
          if (_submissionError != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Container(
                key: const Key('support-submission-error'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFB42318)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_submissionError!)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('support-submit'),
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: _submitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(
              _pendingRequestId == null
                  ? _l10n.supportSendRequest
                  : _l10n.supportRetrySend,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmation(SupportRequestSubmission submission) {
    return Center(
      child: _surface(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            key: const Key('support-confirmation'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 72,
                color: Color(0xFF16A34A),
              ),
              const SizedBox(height: 18),
              Text(
                _l10n.supportRequestSent,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _textDark,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                _l10n.supportThankYou,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _textMuted, height: 1.45),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  submission.reference,
                  key: const Key('support-reference'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                key: const Key('support-back-home'),
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(_l10n.supportBackHome),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final submission = _submission;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: Text(_l10n.supportTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: submission == null
                  ? _buildForm()
                  : _buildConfirmation(submission),
            ),
          ),
        ),
      ),
    );
  }
}
