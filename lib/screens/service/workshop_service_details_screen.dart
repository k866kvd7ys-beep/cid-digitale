import 'dart:io';

import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/services/appointment_requests_service.dart';
import 'package:cid_digitale/services/local_image_cache.dart';
import 'package:cid_digitale/utils/service_booking_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class WheelRepairBookingDraft {
  const WheelRepairBookingDraft({
    required this.wheelType,
    required this.description,
    required this.photos,
  });

  final String wheelType;
  final String description;
  final List<AppointmentRequestImageInput> photos;

  String get encodedServiceDetail => encodeWorkshopWheelRepairDetail(
        wheelType: wheelType,
        description: description,
      );
}

@visibleForTesting
class WheelRepairPhotoCollection {
  WheelRepairPhotoCollection([
    Iterable<AppointmentRequestImageInput> initialPhotos = const [],
  ]) : _photos = List<AppointmentRequestImageInput>.from(initialPhotos) {
    if (_photos.length > maxPhotos) {
      throw ArgumentError.value(
        _photos.length,
        'initialPhotos',
        'A wheel repair request supports at most $maxPhotos photos.',
      );
    }
  }

  static const int maxPhotos = 6;

  final List<AppointmentRequestImageInput> _photos;

  List<AppointmentRequestImageInput> get photos =>
      List<AppointmentRequestImageInput>.unmodifiable(_photos);

  bool get canAdd => _photos.length < maxPhotos;

  bool add(AppointmentRequestImageInput photo) {
    if (!canAdd) return false;
    _photos.add(photo);
    return true;
  }

  AppointmentRequestImageInput removeAt(int index) => _photos.removeAt(index);
}

class WheelRepairServiceScreen extends StatefulWidget {
  const WheelRepairServiceScreen({
    super.key,
    required this.onContinue,
    this.imagePicker,
  });

  final ValueChanged<WheelRepairBookingDraft> onContinue;
  final ImagePicker? imagePicker;

  @override
  State<WheelRepairServiceScreen> createState() =>
      _WheelRepairServiceScreenState();
}

class _WheelRepairServiceScreenState extends State<WheelRepairServiceScreen> {
  static const Color _background = Color(0xFFF6FAFE);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _border = Color(0xFFDCE7F5);

  final _descriptionController = TextEditingController();
  final _photos = WheelRepairPhotoCollection();
  late final ImagePicker _imagePicker;
  String? _selectedWheelType;
  bool _pickingPhoto = false;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _imagePicker = widget.imagePicker ?? ImagePicker();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isNotEmpty ? parts.last : 'wheel.jpg';
  }

  String _sanitizeFileName(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  bool _isSupportedImageName(String value) {
    final lower = value.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif');
  }

  String _mimeTypeForName(String value) {
    final lower = value.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<String> _persistPickedFile(XFile file) async {
    final directory = await getApplicationDocumentsDirectory();
    final targetDirectory = Directory(
      '${directory.path}/wheel_repair_uploads',
    );
    if (!await targetDirectory.exists()) {
      await targetDirectory.create(recursive: true);
    }
    final originalName =
        file.name.isNotEmpty ? file.name : _fileNameFromPath(file.path);
    final targetPath = '${targetDirectory.path}/'
        '${DateTime.now().microsecondsSinceEpoch}_'
        '${_sanitizeFileName(originalName)}';
    await File(targetPath).writeAsBytes(
      await file.readAsBytes(),
      flush: true,
    );
    return targetPath;
  }

  Future<void> _deletePhotoData(AppointmentRequestImageInput photo) async {
    final cacheKey = photo.cacheKey?.trim() ?? '';
    if (cacheKey.isNotEmpty) {
      await LocalImageCache.deleteImage(cacheKey);
    }
    final localPath = photo.localPath?.trim() ?? '';
    if (!kIsWeb && localPath.isNotEmpty) {
      final file = File(localPath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (!_photos.canAdd) {
      _showMessage(_l10n.wheelRepairPhotoLimit);
      return;
    }

    setState(() => _pickingPhoto = true);
    try {
      final file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 92,
      );
      if (file == null) return;

      final fileName =
          file.name.isNotEmpty ? file.name : _fileNameFromPath(file.path);
      if (!_isSupportedImageName(fileName)) {
        _showMessage(_l10n.wheelRepairUnsupportedPhoto);
        return;
      }

      final mimeType = _mimeTypeForName(fileName);
      late final AppointmentRequestImageInput input;
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        final cacheKey = 'wheel_${DateTime.now().microsecondsSinceEpoch}_photo';
        await LocalImageCache.saveImageLocally(cacheKey, bytes);
        input = AppointmentRequestImageInput(
          category: AppointmentRequestImageCategory.otherProblem,
          fileName: fileName,
          mimeType: mimeType,
          previewReference: 'cache:$cacheKey',
          cacheKey: cacheKey,
          bytes: bytes,
        );
      } else {
        final localPath = await _persistPickedFile(file);
        input = AppointmentRequestImageInput(
          category: AppointmentRequestImageCategory.otherProblem,
          fileName: fileName,
          mimeType: mimeType,
          previewReference: localPath,
          localPath: localPath,
        );
      }

      if (!_photos.add(input)) {
        await _deletePhotoData(input);
        _showMessage(_l10n.wheelRepairPhotoLimit);
        return;
      }
      if (mounted) setState(() {});
    } catch (_) {
      _showMessage(_l10n.wheelRepairPhotoError);
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _showPhotoSourceSheet() async {
    if (!_photos.canAdd) {
      _showMessage(_l10n.wheelRepairPhotoLimit);
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
              title: Text(_l10n.wheelRepairTakePhoto),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(_l10n.wheelRepairChoosePhoto),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removePhoto(int index) async {
    final photo = _photos.removeAt(index);
    if (mounted) setState(() {});
    await _deletePhotoData(photo);
  }

  Widget _photoImage(
    AppointmentRequestImageInput photo, {
    BoxFit fit = BoxFit.cover,
  }) {
    final bytes = photo.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(bytes, fit: fit);
    }
    final localPath = photo.localPath?.trim() ?? '';
    if (!kIsWeb && localPath.isNotEmpty) {
      return Image.file(File(localPath), fit: fit);
    }
    final cacheKey = photo.cacheKey?.trim() ?? '';
    if (cacheKey.isNotEmpty) {
      return FutureBuilder<Uint8List?>(
        future: LocalImageCache.getImage(cacheKey),
        builder: (context, snapshot) {
          final cachedBytes = snapshot.data;
          if (cachedBytes == null || cachedBytes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return Image.memory(cachedBytes, fit: fit);
        },
      );
    }
    return const Center(child: Icon(Icons.broken_image_outlined));
  }

  Future<void> _openPreview(AppointmentRequestImageInput photo) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black87,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Center(child: _photoImage(photo, fit: BoxFit.contain)),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: IconButton.filledTonal(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildWheelTypeCard() {
    final theme = Theme.of(context);
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _l10n.wheelRepairTypeLabel,
            style: theme.textTheme.titleMedium?.copyWith(
              color: _textDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          for (final wheelType in workshopWheelRepairTypeKeys) ...[
            _WheelTypeOption(
              key: Key('wheel_type_$wheelType'),
              label: workshopWheelRepairTypeLabel(
                Localizations.localeOf(context).languageCode,
                wheelType,
              ),
              selected: _selectedWheelType == wheelType,
              onTap: () => setState(() => _selectedWheelType = wheelType),
            ),
            if (wheelType != workshopWheelRepairTypeKeys.last)
              const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _photoGuidanceRow(String label, bool recommended) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            recommended ? Icons.check_circle_outline : Icons.circle_outlined,
            size: 19,
            color: recommended ? _primary : _textMuted,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            recommended
                ? _l10n.wheelRepairRecommended
                : _l10n.wheelRepairOptional,
            style: TextStyle(
              color: recommended ? _primary : _textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosCard() {
    final theme = Theme.of(context);
    final photos = _photos.photos;
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tire_repair_outlined, color: _primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _l10n.wheelRepairPhotosTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: _textDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${photos.length}/${WheelRepairPhotoCollection.maxPhotos}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: _textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _l10n.wheelRepairPhotosInfo,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _textMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          _photoGuidanceRow(_l10n.wheelRepairPhotoFull, true),
          _photoGuidanceRow(_l10n.wheelRepairPhotoCloseUp, true),
          _photoGuidanceRow(_l10n.wheelRepairPhotoSecondAngle, false),
          _photoGuidanceRow(_l10n.wheelRepairPhotoAdditional, false),
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: photos.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.05,
              ),
              itemBuilder: (context, index) {
                final photo = photos[index];
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Material(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: Key('wheel_photo_preview_$index'),
                          onTap: () => _openPreview(photo),
                          child: _photoImage(photo),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: IconButton.filled(
                        key: Key('wheel_photo_remove_$index'),
                        tooltip: _l10n.wheelRepairRemovePhoto,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _removePhoto(index),
                        icon: const Icon(Icons.delete_outline, size: 19),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('wheel_photo_add_button'),
              onPressed: _pickingPhoto || !_photos.canAdd
                  ? null
                  : _showPhotoSourceSheet,
              icon: _pickingPhoto
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_a_photo_outlined),
              label: Text(_l10n.wheelRepairAddPhoto),
            ),
          ),
        ],
      ),
    );
  }

  void _continue() {
    final wheelType = _selectedWheelType;
    if (wheelType == null) return;
    widget.onContinue(
      WheelRepairBookingDraft(
        wheelType: wheelType,
        description: _descriptionController.text.trim(),
        photos: _photos.photos,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('wheel_repair_screen'),
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        title: Text(_l10n.workshopServiceWheelRepairTitle),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                Text(
                  _l10n.wheelRepairIntro,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: _textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                _buildWheelTypeCard(),
                const SizedBox(height: 16),
                _buildPhotosCard(),
                const SizedBox(height: 16),
                _sectionCard(
                  child: TextField(
                    key: const Key('wheel_repair_description_field'),
                    controller: _descriptionController,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: _l10n.wheelRepairDamageDescriptionLabel,
                      prefixIcon: const Icon(Icons.description_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('wheel_repair_continue_button'),
                    onPressed: _selectedWheelType == null ? null : _continue,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(_l10n.continueToWorkshopSelection),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OtherWorkshopServiceScreen extends StatefulWidget {
  const OtherWorkshopServiceScreen({
    super.key,
    required this.onContinue,
  });

  final ValueChanged<String> onContinue;

  @override
  State<OtherWorkshopServiceScreen> createState() =>
      _OtherWorkshopServiceScreenState();
}

class _OtherWorkshopServiceScreenState
    extends State<OtherWorkshopServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onContinue(_descriptionController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('other_workshop_service_screen'),
      backgroundColor: const Color(0xFFF6FAFE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6FAFE),
        elevation: 0,
        title: Text(_l10n.workshopServiceOtherTitle),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFDCE7F5)),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _l10n.workshopServiceOtherDescription,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFF64748B),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          key: const Key('other_service_description_field'),
                          controller: _descriptionController,
                          minLines: 4,
                          maxLines: 7,
                          maxLength: 500,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            labelText: _l10n.otherServiceQuestion,
                            hintText: _l10n.otherServicePlaceholder,
                            alignLabelWithHint: true,
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 72),
                              child: Icon(Icons.description_outlined),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          validator: (value) => value?.trim().isEmpty ?? true
                              ? _l10n.otherServiceRequired
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('other_service_continue_button'),
                    onPressed: _continue,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(_l10n.continueToWorkshopSelection),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WheelTypeOption extends StatelessWidget {
  const _WheelTypeOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEFF6FF) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  selected ? const Color(0xFF2563EB) : const Color(0xFFDCE7F5),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF64748B),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
