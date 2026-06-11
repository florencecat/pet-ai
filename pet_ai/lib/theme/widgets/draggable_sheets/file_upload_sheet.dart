import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/file_storage_service.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/base_widgets.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:provider/provider.dart';

class FileUploadSheet extends StatefulWidget {
  const FileUploadSheet({super.key});

  @override
  State<FileUploadSheet> createState() => _FileUploadSheetState();
}

class _FileUploadSheetState extends State<FileUploadSheet> {
  // ── Form ─────────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dateController = TextEditingController();

  DateTime? _selectedDate;
  DocumentCategory? _selectedCategory;
  String? _pickedFilePath;
  String? _pickedFileName;

  bool _isSaving = false;

  // ── History ───────────────────────────────────────────────────────────────
  bool _isLoading = true;
  List<PetDocument> _docs = [];
  String? _petId;

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  // ─── History loading ──────────────────────────────────────────────────────

  Future<void> _loadDocs() async {
    setState(() => _isLoading = true);
    final petId = await PetService().getActiveProfileId();
    if (petId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final docs = await FileStorageService().loadDocuments(petId);
    if (mounted) {
      setState(() {
        _petId = petId;
        _docs = docs;
        _isLoading = false;
      });
    }
  }

  // ─── File picking ─────────────────────────────────────────────────────────

  Future<void> _showSourcePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SourcePickerSheet(
        onPickFile: _pickFromFiles,
        onTakePhoto: _takePhoto,
      ),
    );
  }

  Future<void> _pickFromFiles() async {
    Navigator.pop(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _pickedFilePath = result.files.single.path!;
          _pickedFileName = result.files.single.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Не удалось выбрать файл: $e')));
      }
    }
  }

  Future<void> _takePhoto() async {
    Navigator.pop(context);
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (image != null) {
        setState(() {
          _pickedFilePath = image.path;
          _pickedFileName = image.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сделать снимок: $e')),
        );
      }
    }
  }

  // ─── Date picker ──────────────────────────────────────────────────────────

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2000),
      lastDate: now.add(const Duration(days: 365 * 5)),
      locale: const Locale('ru'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = formatSmartDate(picked, pattern: 'd MMMM yyyy', locale: 'ru_RU');
      });
    }
  }

  // ─── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Укажите дату документа')));
      return;
    }
    if (_pickedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Прикрепите файл или сделайте снимок')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final petId = await PetService().getActiveProfileId();
      if (petId == null) throw Exception('Нет активного профиля');

      await FileStorageService().addDocument(
        petId: petId,
        name: _nameController.text.trim(),
        date: _selectedDate!,
        sourcePath: _pickedFilePath!,
        category: _selectedCategory,
      );

      // Clear form and reload history — stay in sheet
      _nameController.clear();
      _dateController.clear();
      setState(() {
        _selectedDate = null;
        _selectedCategory = null;
        _pickedFilePath = null;
        _pickedFileName = null;
      });
      await _loadDocs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Open ───────────────────────────────────────────────────────────────

  Future<void> _open(BuildContext context, PetDocument doc) async {
    if (!doc.file.existsSync()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл не найден на устройстве')),
        );
      }
      return;
    }
    if (doc.isImage && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => _ImagePreviewDialog(doc: doc),
      );
      return;
    }
    final result = await OpenFilex.open(doc.filePath);
    if (result.type != ResultType.done && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть файл: ${result.message}')),
      );
    }
  }

  // ─── Delete ───────────────────────────────────────────────────────────────

  Future<void> _delete(PetDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить документ?'),
        content: Text(
          '«${doc.name}» будет удалён без возможности восстановления.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ThemeColors.dangerZone,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || _petId == null) return;
    await FileStorageService().deleteDocument(_petId!, doc);
    await _loadDocs();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableSheet(
      title: 'Документы',
      centerTitle: true,
      initialSize: 0.85,
      maxSize: 1.0,
      onBack: () => Navigator.of(context).pop(true),
      actions: [
        if (_isSaving)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.check),
            color: context.watch<AppearanceController>().primaryColor,
            onPressed: _save,
          ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── New document form ────────────────────────────────────────────
          GlassPlate(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Новый документ',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Name
                    TextFormField(
                      controller: _nameController,
                      decoration: baseInputDecoration('Название документа'),
                      style: Theme.of(context).textTheme.bodyMedium,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Введите название'
                          : null,
                      textCapitalization: TextCapitalization.sentences,
                    ),

                    const SizedBox(height: 8),

                    // Date
                    TextFormField(
                      keyboardType: TextInputType.none,
                      onTap: _selectDate,
                      controller: _dateController,
                      decoration: baseInputDecoration(
                        'Дата документа',
                        suffixIcon: Icon(
                          Icons.calendar_today,
                          color: Theme.of(context).dividerColor,
                          size: 18,
                        ),
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Выберите дату'
                          : null,
                    ),

                    const SizedBox(height: 12),

                    // Category
                    Text(
                      'Категория (необязательно)',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: DocumentCategories.all.map((cat) {
                        return SoftGlassBadge(
                          color: cat.color,
                          icon: cat.icon,
                          label: cat.name,
                          selected: _selectedCategory == cat,
                          onChanged: (selected) {
                            setState(() {
                              _selectedCategory = selected ? cat : null;
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 12),

                    // File attach
                    if (_pickedFilePath == null)
                      _AttachButton(onTap: _showSourcePicker)
                    else
                      _FilePreview(
                        filePath: _pickedFilePath!,
                        fileName: _pickedFileName ?? '',
                        onRemove: () => setState(() {
                          _pickedFilePath = null;
                          _pickedFileName = null;
                        }),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Document history ─────────────────────────────────────────────
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_docs.isEmpty)
            _EmptyHistoryState()
          else ...[
            Text('История', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._docs.map(
              (doc) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassListTile(
                  callback: () => _open(context, doc),
                  icon: doc.isImage ? null : doc.fileIcon,
                  customIcon: doc.isImage && doc.file.existsSync()
                      ? Image.file(
                          doc.file,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        )
                      : null,
                  iconColor:
                      doc.category?.color ??
                      context.watch<AppearanceController>().primaryColor,
                  title: doc.name,
                  subtitle: formatSmartDate(doc.date),
                  bottomBadge: doc.category == null
                      ? null
                      : SoftGlassBadge(
                          color: doc.category!.color,
                          label: doc.category!.name,
                        ),
                  trailing: DeleteIconButton(callback: () => _delete(doc)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Кнопка «прикрепить» ──────────────────────────────────────────────────────

class _AttachButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AttachButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppearanceController>().primaryColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withAlpha(120),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          color: color.withAlpha(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.attach_file_rounded, color: color, size: 32),
            const SizedBox(height: 6),
            Text(
              'Прикрепить файл или снимок',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Превью прикреплённого файла ─────────────────────────────────────────────

class _FilePreview extends StatelessWidget {
  final String filePath;
  final String fileName;
  final VoidCallback onRemove;

  const _FilePreview({
    required this.filePath,
    required this.fileName,
    required this.onRemove,
  });

  bool get _isImage {
    final ext = fileName.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppearanceController>().primaryColor;
    return GlassPlate(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _isImage
                  ? Image.file(
                      File(filePath),
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      color: color.withAlpha(30),
                      child: Icon(
                        Icons.insert_drive_file_outlined,
                        color: color,
                        size: 32,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                fileName,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              color: context.watch<AppearanceController>().secondaryColor,
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Пустое состояние ────────────────────────────────────────────────────────

class _EmptyHistoryState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppearanceController>().primaryColor;
    return SizedBox(
      height: 160,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 56,
              color: color.withAlpha(60),
            ),
            const SizedBox(height: 12),
            Text(
              'Документов пока нет',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge!.copyWith(color: color.withAlpha(120)),
            ),
            const SizedBox(height: 4),
            Text(
              'Добавьте паспорт, справки и сертификаты',
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: context
                    .watch<AppearanceController>()
                    .secondaryColor
                    .withAlpha(150),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Full-screen image preview ────────────────────────────────────────────────

class _ImagePreviewDialog extends StatelessWidget {
  final PetDocument doc;
  const _ImagePreviewDialog({required this.doc});

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(
            doc.name,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.file(doc.file, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

// ─── Выбор источника файла ───────────────────────────────────────────────────

class SourcePickerSheet extends StatelessWidget {
  final VoidCallback onPickFile;
  final VoidCallback onTakePhoto;

  const SourcePickerSheet({
    required this.onPickFile,
    required this.onTakePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: ThemeColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Источник файла',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SourceTile(
                  icon: Icons.folder_open_rounded,
                  label: 'Из файлов',
                  color: context.watch<AppearanceController>().primaryColor,
                  onTap: onPickFile,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SourceTile(
                  icon: Icons.camera_alt_rounded,
                  label: 'Сделать снимок',
                  color: const Color(0xFF00897B),
                  onTap: onTakePhoto,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
