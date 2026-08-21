import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStorageService {
  static const _appointmentsKey = 'kingo_medico_appointments';
  static const _medicinesKey = 'kingo_medico_medicines';
  static const _documentsKey = 'kingo_medico_documents';
  static const _selectedPlanKey = 'kingo_medico_selected_plan';

  Future<List<Map<String, dynamic>>> loadAppointments() async {
    return _loadList(_appointmentsKey);
  }

  Future<void> saveAppointments(List<Map<String, dynamic>> data) async {
    await _saveList(_appointmentsKey, data);
  }

  Future<List<Map<String, dynamic>>> loadMedicines() async {
    return _loadList(_medicinesKey);
  }

  Future<void> saveMedicines(List<Map<String, dynamic>> data) async {
    await _saveList(_medicinesKey, data);
  }

  Future<List<Map<String, dynamic>>> loadDocuments() async {
    return _loadList(_documentsKey);
  }

  Future<void> saveDocuments(List<Map<String, dynamic>> data) async {
    await _saveList(_documentsKey, data);
  }

  Future<String> getSelectedPlan() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedPlanKey) ?? 'FREE';
  }

  Future<void> setSelectedPlan(String plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedPlanKey, plan);
  }

  Future<String> archiveFile(String sourcePath, String originalName) async {
    final directory = await getApplicationDocumentsDirectory();
    final docsDirectory = Directory('${directory.path}/medical_documents');
    if (!await docsDirectory.exists()) {
      await docsDirectory.create(recursive: true);
    }

    final safeName = originalName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final destination = File('${docsDirectory.path}/$fileName');
    await File(sourcePath).copy(destination.path);
    return destination.path;
  }

  Future<void> deleteArchivedFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<List<Map<String, dynamic>>> _loadList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _saveList(String key, List<Map<String, dynamic>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }
}
