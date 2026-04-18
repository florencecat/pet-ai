import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pet_ai/services/file_storage_service.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/theme/widgets/base_widgets.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';

class FileUploadSheet extends StatefulWidget {
  const FileUploadSheet({super.key});

  @override
  State<FileUploadSheet> createState() => _FileUploadSheetState();
}

class _FileUploadSheetState extends State<FileUploadSheet> {
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
    super.dispose();
  }

  // ─── Выбор файла ──────────────────────────────────────────────────────────

  Future<void> _showSourcePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SourcePickerSheet(
        onPickFile: _pickFromFiles,
        onTakePhoto: _takePhoto,
      ),
    );
  }

  Future<void> _pickFromFiles() async {
    Navigator.pop(context); // закрываем _SourcePickerSheet
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
    Navigator.pop(context); // закрываем _SourcePickerSheet
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

  // ─── Выбор даты ───────────────────────────────────────────────────────────

  // ─── Сохранение ───────────────────────────────────────────────────────────

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
        _dateController.text = DateFormat(
          'd MMMM yyyy',
          'ru_RU',
        ).format(_selectedDate!);
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

    setState(() => _isSaving = true);

    try {
      final petId = await ProfileService().getActiveProfileId();
      if (petId == null) throw Exception('Нет активного профиля');

      await FileStorageService().addDocument(
        petId: petId,
        name: _nameController.text.trim(),
        date: _selectedDate!,
        sourcePath: _pickedFilePath!,
        category: _selectedCategory,
      );

      if (mounted) Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    return DraggableSheet(
      title: 'Новый документ',
      centerTitle: true,
      initialSize: 0.75,
      onBack: () => Navigator.of(context).pop(false),
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
            color: ThemeColors.primary,
            onPressed: _save,
          ),
      ],
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Название (обязательно) ────────────────────────────────────
            TextFormField(
              controller: _nameController,
              decoration: baseInputDecoration('Название документа'),
              style: Theme.of(context).textTheme.bodyMedium,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Введите название' : null,
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: 8),

            // ── Дата (обязательна) ────────────────────────────────────────
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
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Выберите дату' : null,
            ),

            const SizedBox(height: 8),

            // ── Категория (опционально) ───────────────────────────────────

            Container(
              decoration: BoxDecoration(
                color: ThemeColors.white,
                borderRadius: BorderRadius.circular(16)

              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Категория (необязательно)',
                      style: Theme.of(context).textTheme.bodySmall,
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
                            onChanged: (selected) { setState(() {
                              _selectedCategory = selected ? cat : null;
                            });});
                        // return FilterChip(
                        //   avatar: Icon(
                        //     cat.icon,
                        //     size: 16,
                        //     color: selected ? Colors.white : cat.color,
                        //   ),
                        //   label: Text(cat.name),
                        //   selected: selected,
                        //   selectedColor: cat.color.withAlpha(200),
                        //   backgroundColor: Colors.white.withAlpha(150),
                        //   labelStyle: TextStyle(
                        //     fontSize: 12,
                        //     color: selected
                        //         ? Colors.white
                        //         : ThemeColors.textPrimary,
                        //   ),
                        //   checkmarkColor: Colors.white,
                        //   onSelected: (_) {
                        //     setState(() {
                        //       // повторный тап снимает выбор
                        //       _selectedCategory = selected ? null : cat;
                        //     });
                        //   },
                        // );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // GlassPlate(
            //   child: ,
            // ),

            const SizedBox(height: 8),

            // ── Прикрепить файл ───────────────────────────────────────────
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
    );
  }
}

// ─── Кнопка «прикрепить» ──────────────────────────────────────────────────────

class _AttachButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AttachButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ThemeColors.primary.withAlpha(120),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          color: ThemeColors.primary.withAlpha(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.attach_file_rounded,
              color: ThemeColors.primary,
              size: 32,
            ),
            const SizedBox(height: 6),
            Text(
              'Прикрепить файл или снимок',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: ThemeColors.primary,
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
    return GlassPlate(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            // Превью или иконка
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
                      color: ThemeColors.primary.withAlpha(30),
                      child: Icon(
                        Icons.insert_drive_file_outlined,
                        color: ThemeColors.primary,
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
              color: ThemeColors.secondary,
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Выбор источника файла ───────────────────────────────────────────────────

class _SourcePickerSheet extends StatelessWidget {
  final VoidCallback onPickFile;
  final VoidCallback onTakePhoto;

  const _SourcePickerSheet({
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
                  color: ThemeColors.primary,
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
