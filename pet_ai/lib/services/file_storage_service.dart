import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Категории документов ────────────────────────────────────────────────────

class DocumentCategory {
  final String id;
  final String name;
  final IconData icon;
  final int colorValue;

  const DocumentCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorValue,
  });

  Color get color => Color(colorValue);
}

class DocumentCategories {
  static const vaccination = DocumentCategory(
    id: 'vaccination',
    name: 'Вакцинация',
    icon: Icons.vaccines,
    colorValue: 0xFFD32F2F,
  );
  static const health = DocumentCategory(
    id: 'health',
    name: 'Справка о здоровье',
    icon: Icons.medical_information,
    colorValue: 0xFF1E88E5,
  );
  static const insurance = DocumentCategory(
    id: 'insurance',
    name: 'Страховка',
    icon: Icons.security,
    colorValue: 0xFF43A047,
  );
  static const pedigree = DocumentCategory(
    id: 'pedigree',
    name: 'Родословная',
    icon: Icons.account_tree,
    colorValue: 0xFF7B1FA2,
  );
  static const passport = DocumentCategory(
    id: 'passport',
    name: 'Паспорт питомца',
    icon: Icons.book,
    colorValue: 0xFFFF9800,
  );
  static const analysis = DocumentCategory(
    id: 'analysis',
    name: 'Анализы',
    icon: Icons.science,
    colorValue: 0xFF00897B,
  );
  static const other = DocumentCategory(
    id: 'other',
    name: 'Другое',
    icon: Icons.folder,
    colorValue: 0xFF607D8B,
  );

  static const all = [
    vaccination,
    health,
    insurance,
    pedigree,
    passport,
    analysis,
    other,
  ];

  static DocumentCategory byId(String id) =>
      all.firstWhere((c) => c.id == id, orElse: () => other);
}

// ─── Модель документа ─────────────────────────────────────────────────────────

class PetDocument {
  final String id;
  String name;
  DateTime date;
  DocumentCategory? category;
  /// Путь к копии файла в директории приложения
  String filePath;
  /// Оригинальное имя файла (для отображения)
  String fileName;
  final DateTime addedAt;

  PetDocument({
    required this.id,
    required this.name,
    required this.date,
    required this.filePath,
    required this.fileName,
    this.category,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  File get file => File(filePath);

  bool get isImage {
    final ext = p.extension(fileName).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic'].contains(ext);
  }

  IconData get fileIcon {
    final ext = p.extension(fileName).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic'].contains(ext)) {
      return Icons.image_outlined;
    }
    if (ext == '.pdf') return Icons.picture_as_pdf_outlined;
    if (['.doc', '.docx'].contains(ext)) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'date': date.toIso8601String(),
    'category': category?.id,
    'filePath': filePath,
    'fileName': fileName,
    'addedAt': addedAt.toIso8601String(),
  };

  factory PetDocument.fromJson(Map<String, dynamic> json) => PetDocument(
    id: json['id'] as String,
    name: json['name'] as String,
    date: DateTime.parse(json['date'] as String),
    filePath: json['filePath'] as String,
    fileName: json['fileName'] as String? ?? p.basename(json['filePath'] as String),
    category: json['category'] != null
        ? DocumentCategories.byId(json['category'] as String)
        : null,
    addedAt: json['addedAt'] != null
        ? DateTime.parse(json['addedAt'] as String)
        : DateTime.now(),
  );
}

// ─── Сервис ───────────────────────────────────────────────────────────────────

class FileStorageService {
  static String _key(String petId) => 'pet_documents:$petId';

  // ─── Чтение ────────────────────────────────────────────────────────────────

  Future<List<PetDocument>> loadDocuments(String petId) async {
    final data =
        await SharedPreferencesAsync().getStringList(_key(petId)) ?? [];
    final docs = data
        .map((e) {
          try {
            return PetDocument.fromJson(jsonDecode(e));
          } catch (_) {
            return null;
          }
        })
        .whereType<PetDocument>()
        .toList();
    // Сортируем по дате документа (новые сверху)
    docs.sort((a, b) => b.date.compareTo(a.date));
    return docs;
  }

  // ─── Запись ────────────────────────────────────────────────────────────────

  Future<void> _persist(String petId, List<PetDocument> docs) async {
    final encoded = docs.map((d) => jsonEncode(d.toJson())).toList();
    await SharedPreferencesAsync().setStringList(_key(petId), encoded);
  }

  /// Копирует файл [sourcePath] в директорию приложения и сохраняет метаданные.
  Future<PetDocument> addDocument({
    required String petId,
    required String name,
    required DateTime date,
    required String sourcePath,
    DocumentCategory? category,
  }) async {
    final originalName = p.basename(sourcePath);
    final docId = DateTime.now().millisecondsSinceEpoch.toString();
    final savedPath = await _copyToAppDir(petId, docId, sourcePath);

    final doc = PetDocument(
      id: docId,
      name: name,
      date: date,
      filePath: savedPath,
      fileName: originalName,
      category: category,
    );

    final docs = await loadDocuments(petId);
    docs.add(doc);
    await _persist(petId, docs);
    return doc;
  }

  Future<void> deleteDocument(String petId, PetDocument doc) async {
    // Удаляем физический файл
    try {
      final f = File(doc.filePath);
      if (await f.exists()) await f.delete();
    } catch (_) {}

    final docs = await loadDocuments(petId);
    docs.removeWhere((d) => d.id == doc.id);
    await _persist(petId, docs);
  }

  Future<void> clearAll(String petId) async {
    final docs = await loadDocuments(petId);
    for (final doc in docs) {
      try {
        final f = File(doc.filePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    await SharedPreferencesAsync().remove(_key(petId));
  }

  // ─── Вспомогательные ──────────────────────────────────────────────────────

  Future<String> _copyToAppDir(
      String petId, String docId, String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = p.extension(sourcePath);
    final sanitizedPetId = petId.replaceAll(RegExp(r'[^\w]'), '_');
    final destPath = '${dir.path}/doc_${sanitizedPetId}_$docId$ext';
    await File(sourcePath).copy(destPath);
    return destPath;
  }
}
