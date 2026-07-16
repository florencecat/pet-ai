import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/file_storage_service.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/activity_indicator.dart';
import 'package:pet_satellite/theme/widgets/base_widgets.dart';
import 'package:pet_satellite/theme/widgets/confirm_delete.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:provider/provider.dart';

class FileUploadDialog extends StatefulWidget {
  const FileUploadDialog({super.key});

  @override
  State<FileUploadDialog> createState() => _FileUploadDialogState();
}

class _FileUploadDialogState extends State<FileUploadDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _dateController = TextEditingController();

  DateTime? _selectedDate;
  DocumentCategory? _selectedCategory;
  String? _pickedFilePath;
  String? _pickedFileName;

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _showSourcePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SourcePickerSheet(
        onPickFile: _pickFromFiles,
        onPickFromGallery: _pickFromGallery,
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

  Future<void> _pickFromGallery() async {
    Navigator.pop(context);
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
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

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      locale: const Locale('ru'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = formatSmartDate(
          picked,
          pattern: 'd MMMM yyyy',
          locale: 'ru_RU',
        );
      });
    }
  }

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

    setState(() {
      _isSaving = true;
    });

    bool error = false;
    try {
      final petId = await PetProfileService().getActiveProfileId();
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
      }
      error = true;
    } finally {
      if (!error && mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: context.watch<AppearanceController>().primaryColor,
          ),
          child: const Text('Сохранить'),
        ),
      ],
      title: Text(
        'Новый документ',
        style: Theme.of(context).textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      content: InlineLoading(
        isLoading: _isSaving,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: baseInputDecoration(context, hint: 'Название документа'),
                style: Theme.of(context).textTheme.bodyMedium,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Введите название' : null,
                textCapitalization: TextCapitalization.sentences,
              ),

              const SizedBox(height: 8),

              // Date
              TextFormField(
                keyboardType: TextInputType.none,
                onTap: _selectDate,
                controller: _dateController,
                decoration: baseInputDecoration(
                  context,
                  hint: 'Дата документа',
                  suffixIcon: Icon(
                    Icons.calendar_today,
                    color: Theme.of(context).dividerColor,
                    size: 18,
                  ),
                ),
                style: Theme.of(context).textTheme.bodyMedium,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Выберите дату' : null,
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
                SoftGlassButton(
                  icon: Icons.attach_file_outlined,
                  title: 'Прикрепить файл или снимок',
                  onTap: _showSourcePicker,
                )
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
    );
  }
}

class FileUploadSheet extends StatefulWidget {
  const FileUploadSheet({super.key});

  @override
  State<FileUploadSheet> createState() => _FileUploadSheetState();
}

class _FileUploadSheetState extends State<FileUploadSheet> {
  bool _isLoading = true;
  List<PetDocument> _docs = [];
  String? _petId;

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  Future<void> _showUploadFileDialog(BuildContext context) async {
    final uploaded = await showDialog<bool>(
      context: context,
      builder: (_) => FileUploadDialog(),
    );
    if (uploaded != null && uploaded) {
      await _loadDocs();
    }
  }

  Future<void> _loadDocs() async {
    setState(() => _isLoading = true);
    final petId = await PetProfileService().getActiveProfileId();
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
    final confirmed = await confirmDelete(
      context,
      title: 'Удалить документ?',
      message: '«${doc.name}» будет удалён без возможности восстановления.',
    );
    if (!confirmed || _petId == null) return;
    await FileStorageService().deleteDocument(_petId!, doc);
    await _loadDocs();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppearanceController>().primaryColor;

    return DraggableSheet(
      title: 'Документы',
      centerTitle: true,
      initialSize: _docs.isEmpty ? 0.2 : 0.6,
      maxSize: 0.6,
      onBack: () => Navigator.of(context).pop(true),
      body: InlineLoading(
        isLoading: _isLoading,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_docs.isEmpty)
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Icon(
                    Icons.folder_open_rounded,
                    size: 72,
                    color: color.withAlpha(192),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Нет документов.',
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          inherit: true,
                          color: context
                              .watch<AppearanceController>()
                              .secondaryColor
                              .withAlpha(60),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsetsGeometry.all(5),
                        ),
                        onPressed: () => _showUploadFileDialog(context),
                        child: Text(
                          'Добавить',
                          style: Theme.of(context).textTheme.titleLarge!
                              .copyWith(
                                inherit: true,
                                color: context
                                    .watch<AppearanceController>()
                                    .primaryColor
                                    .withAlpha(192),
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else ...[
              SoftGlassButton(
                icon: Icons.file_present_outlined,
                title: 'Добавить файл',
                subtitle: 'Храните важные документы в одном месте',
                onTap: () async => await _showUploadFileDialog(context),
              ),
              SizedBox(height: 16),
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
                    iconColor: doc.category?.color ?? color,
                    title: doc.name,
                    subtitle: formatSmartDate(doc.date),
                    bottomBadge: doc.category == null
                        ? null
                        : SoftGlassBadge(
                            icon: doc.category!.icon,
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
  final VoidCallback onPickFromGallery;
  final VoidCallback onTakePhoto;

  const SourcePickerSheet({
    super.key,
    required this.onPickFile,
    required this.onPickFromGallery,
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
            spacing: 8,
            children: [
              Expanded(
                child: GlassSourceCard(
                  type: SourceCardType.camera,
                  color: ThemeColors.cameraImageSource,
                  onTap: onTakePhoto,
                ),
              ),
              Expanded(
                child: GlassSourceCard(
                  type: SourceCardType.gallery,
                  color: ThemeColors.galleryImageSource,
                  onTap: onPickFromGallery,
                ),
              ),
              Expanded(
                child: GlassSourceCard(
                  type: SourceCardType.files,
                  color: context.watch<AppearanceController>().primaryColor,
                  onTap: onPickFile,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
