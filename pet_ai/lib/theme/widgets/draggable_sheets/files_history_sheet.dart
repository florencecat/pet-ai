import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_ai/services/file_storage_service.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';

class FilesHistorySheet extends StatefulWidget {
  const FilesHistorySheet({super.key});

  @override
  State<FilesHistorySheet> createState() => _FilesHistorySheetState();
}

class _FilesHistorySheetState extends State<FilesHistorySheet> {
  bool _isLoading = true;
  List<PetDocument> _docs = [];
  String? _petId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final petId = await ProfileService().getActiveProfileId();
    if (petId == null) {
      setState(() => _isLoading = false);
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

  Future<void> _delete(PetDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить документ?'),
        content: Text('«${doc.name}» будет удалён без возможности восстановления.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ThemeColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || _petId == null) return;
    await FileStorageService().deleteDocument(_petId!, doc);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableSheet(
      title: 'Документы',
      centerTitle: true,
      initialSize: 0.7,
      maxSize: 0.95,
      onBack: () => Navigator.of(context).pop(),
      body: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          : _docs.isEmpty
              ? _EmptyState()
              : Column(
                  children: _docs.map((doc) => _DocCard(
                    doc: doc,
                    onDelete: () => _delete(doc),
                  )).toList(),
                ),
    );
  }
}

// ─── Карточка документа ──────────────────────────────────────────────────────

class _DocCard extends StatelessWidget {
  final PetDocument doc;
  final VoidCallback onDelete;

  const _DocCard({required this.doc, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cat = doc.category;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPlate(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Превью / иконка ──────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _buildThumbnail(),
              ),

              const SizedBox(width: 12),

              // ── Метаданные ───────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.name,
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: ThemeColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('d MMMM yyyy', 'ru_RU').format(doc.date),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (cat != null) ...[
                      const SizedBox(height: 6),
                      _CategoryBadge(category: cat),
                    ],
                  ],
                ),
              ),

              // ── Удалить ──────────────────────────────────────────────
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: ThemeColors.danger.withAlpha(180),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final file = doc.file;
    if (doc.isImage && file.existsSync()) {
      return Image.file(
        file,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
      );
    }
    final cat = doc.category;
    return Container(
      width: 64,
      height: 64,
      color: (cat?.color ?? ThemeColors.primary).withAlpha(30),
      child: Icon(
        doc.fileIcon,
        size: 32,
        color: cat?.color ?? ThemeColors.primary,
      ),
    );
  }
}

// ─── Бейдж категории ─────────────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  final DocumentCategory category;
  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: category.color.withAlpha(40),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: category.color.withAlpha(100), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 12, color: category.color),
          const SizedBox(width: 4),
          Text(
            category.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: category.color.withAlpha(220),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Пустое состояние ────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 72,
              color: ThemeColors.primary.withAlpha(60),
            ),
            const SizedBox(height: 12),
            Text(
              'Документов пока нет',
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                color: ThemeColors.primary.withAlpha(120),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Добавьте паспорт, справки и сертификаты',
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: ThemeColors.secondary.withAlpha(150),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
