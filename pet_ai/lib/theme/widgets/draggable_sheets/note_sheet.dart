import 'package:flutter/material.dart';
import 'package:pet_satellite/models/note.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/activity_indicator.dart';
import 'package:pet_satellite/theme/widgets/base_widgets.dart';
import 'package:pet_satellite/theme/widgets/confirm_delete.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/theme/widgets/hold_to_talk_mic.dart';
import 'package:provider/provider.dart';
import 'package:pet_satellite/models/pet_profile.dart';

class NoteDialog extends StatefulWidget {
  final Pet profile;

  const NoteDialog({super.key, required this.profile});

  @override
  State<NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<NoteDialog> {
  final TextEditingController _controller = TextEditingController();

  bool _isSaving = false;
  SymptomTag? _selectedSymptom;

  void _onVoiceText(String words) {
    setState(() {
      _controller.text = words;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _selectedSymptom == null) return;

    final noteText = text.isNotEmpty ? text : (_selectedSymptom?.label ?? '');
    setState(() => _isSaving = true);

    bool error = false;
    try {
      await PetProfileService().addNote(
        widget.profile.id,
        noteText,
        symptomId: _selectedSymptom?.id,
      );
    } catch (e) {
      error = true;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        if (!error) Navigator.of(context).pop(true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasContent =
        _controller.text.trim().isNotEmpty || _selectedSymptom != null;

    return AlertDialog(
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: hasContent && !_isSaving ? _save : null,
          style: FilledButton.styleFrom(
            backgroundColor: context.watch<AppearanceController>().primaryColor,
          ),
          child: const Text('Сохранить'),
        ),
      ],
      title: Text(
        'Новая заметка',
        style: Theme.of(context).textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      content: InlineLoading(
        isLoading: _isSaving,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Quick symptom chips ───────────────────────────────────────
              Text(
                'Быстрая фиксация симптома',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: SymptomTags.all.map((tag) {
                  return SoftGlassBadge(
                    color: tag.color,
                    icon: tag.icon,
                    label: tag.label,
                    selected: _selectedSymptom == tag,
                    onChanged: (isSelected) {
                      setState(() {
                        _selectedSymptom = isSelected ? tag : null;
                        _controller.text = isSelected ? tag.label : '';
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // ── Text input + mic ──────────────────────────────────────────
              TextField(
                controller: _controller,
                maxLines: 8,
                minLines: 4,
                keyboardType: TextInputType.multiline,
                decoration: baseInputDecoration(context, hint: 'Своя заметка'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: HoldToTalkMic(
                  onText: _onVoiceText,
                  activeColor: ThemeColors.dangerZone,
                  idleColor: context
                      .watch<AppearanceController>()
                      .secondaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NoteSheet extends StatefulWidget {
  final Pet profile;

  const NoteSheet({super.key, required this.profile});

  @override
  State<NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<NoteSheet> {
  late NoteHistory _history;

  @override
  void initState() {
    super.initState();
    _history = widget.profile.noteHistory;
  }

  Future<void> _showAddDialog() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => NoteDialog(profile: widget.profile),
    );
    if (added == true) await _reload();
  }

  Future<void> _reload() async {
    final updated = await PetProfileService().loadProfile(widget.profile.id);
    if (updated != null && mounted) {
      setState(() => _history = updated.noteHistory);
    }
  }

  Future<void> _delete(NoteEntry entry) async {
    final confirmed = await confirmDelete(context, title: 'Удалить заметку?');
    if (!confirmed) return;
    await PetProfileService().deleteNoteEntry(widget.profile.id, entry.id);
    if (mounted) setState(() => _history.deleteById(entry.id));
  }

  @override
  Widget build(BuildContext context) {
    final entries = List<NoteEntry>.from(_history.entries.reversed);
    final color = context.watch<AppearanceController>().primaryColor;

    return DraggableSheet(
      title: 'Заметки',
      centerTitle: true,
      initialSize: null,
      maxSize: 0.75,
      onBack: () => Navigator.of(context).pop(true),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (entries.isEmpty)
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.max,
              children: [
                Icon(Icons.notes, size: 72, color: color.withAlpha(192)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Нет заметок.',
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
                        padding: const EdgeInsets.all(5),
                      ),
                      onPressed: _showAddDialog,
                      child: Text(
                        'Добавить',
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          inherit: true,
                          color: color.withAlpha(192),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else ...[
            SoftGlassButton(
              icon: Icons.note_add_outlined,
              title: 'Добавить заметку',
              subtitle: 'Фиксируйте симптомы и наблюдения',
              onTap: _showAddDialog,
            ),
            const SizedBox(height: 16),
            ...entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassListTile(
                  icon: e.symptomTag?.icon ?? Icons.notes,
                  iconColor: e.symptomTag?.color.withAlpha(15) ?? Colors.white,
                  title: e.note,
                  subtitle: formatSmartDateTime(e.date),
                  trailing: DeleteIconButton(callback: () => _delete(e)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
