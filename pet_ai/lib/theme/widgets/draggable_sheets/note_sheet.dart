import 'package:flutter/material.dart';
import 'package:pet_satellite/models/note.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/base_widgets.dart';
import 'package:pet_satellite/theme/widgets/confirm_delete.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/theme/widgets/hold_to_talk_mic.dart';
import 'package:provider/provider.dart';
import 'package:pet_satellite/models/pet_profile.dart';

class NoteSheet extends StatefulWidget {
  final Pet profile;

  const NoteSheet({super.key, required this.profile});

  @override
  State<NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<NoteSheet> {
  final TextEditingController _controller = TextEditingController();

  bool _isSaving = false;
  SymptomTag? _selectedSymptom;

  late NoteHistory _history;

  @override
  void initState() {
    super.initState();
    _history = widget.profile.noteHistory;
  }

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
    try {
      await PetService().addNote(
        widget.profile.id,
        noteText,
        symptomId: _selectedSymptom?.id,
      );
      if (mounted) {
        // Stay in sheet — reload history and clear form
        final updated = await PetService().loadProfile(widget.profile.id);
        if (updated != null && mounted) {
          setState(() {
            _history = updated.noteHistory;
            _controller.clear();
            _selectedSymptom = null;
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete(NoteEntry entry) async {
    final confirmed = await confirmDelete(context, title: 'Удалить заметку?');
    if (!confirmed) return;
    await PetService().deleteNoteEntry(widget.profile.id, entry.date);
    if (mounted) setState(() => _history.deleteEntry(entry.date));
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
    final entries = List<NoteEntry>.from(_history.entries.reversed);

    return DraggableSheet(
      title: 'Дневник',
      centerTitle: true,
      initialSize: 0.9,
      maxSize: 1.0,
      onBack: () => Navigator.of(context).pop(true),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Quick symptom chips ───────────────────────────────────────
          GlassPlate(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Быстрая фиксация симптома',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: SymptomTags.all.map((tag) {
                      return SoftGlassBadge(
                        color: tag.color,
                        icon: tag.icon,
                        label: tag.label,
                        selected: _selectedSymptom == tag,
                        onChanged: (isSelected) {
                          setState(() {
                            _selectedSymptom = isSelected ? tag : null;

                            if (isSelected && _controller.text.isEmpty) {
                              _controller.text = tag.label;
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Text input + mic ──────────────────────────────────────────
          GlassPlate(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: _controller,
                    maxLines: 4,
                    minLines: 2,
                    keyboardType: TextInputType.multiline,
                    decoration:
                        baseInputDecoration(
                          'Своя заметка (или уточнение к симптому) ...',
                        ).copyWith(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // ── Добавить ──────────────────────────────────────────
                      FilledButton.icon(
                        onPressed: hasContent && !_isSaving ? _save : null,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.add, size: 18),
                        label: const Text('Добавить'),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              context.watch<AppearanceController>().primaryColor,
                          disabledBackgroundColor: context
                              .watch<AppearanceController>()
                              .secondaryColor
                              .withAlpha(60),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                      HoldToTalkMic(
                        onText: _onVoiceText,
                        activeColor: ThemeColors.dangerZone,
                        idleColor: context
                            .watch<AppearanceController>()
                            .secondaryColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── History ───────────────────────────────────────────────────
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.notes,
                      size: 52,
                      color: context
                          .watch<AppearanceController>()
                          .primaryColor
                          .withAlpha(60),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'История дневника пуста',
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        color: context
                            .watch<AppearanceController>()
                            .primaryColor
                            .withAlpha(120),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Text('История', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
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
