// KINGO MEDICO RC1.1 TESTER + LIMITATORE
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'services/app_storage_service.dart';
import 'services/medical_ai_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  runApp(const KingoMedicoApp());
}

class KingoMedicoApp extends StatelessWidget {
  const KingoMedicoApp({super.key});

  static const primary = Color(0xFF0B6E99);
  static const secondary = Color(0xFF1696A8);
  static const soft = Color(0xFFEAF6F8);
  static const text = Color(0xFF18313B);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KINGO Medico',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6FAFB),
        colorScheme: ColorScheme.fromSeed(seedColor: primary),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF6FAFB),
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _activateTester(BuildContext context) async {
    final controller = TextEditingController();
    final storage = AppStorageService();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modalità TESTER KOL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Funzione riservata ai test interni. Inserisci il codice tester.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Codice tester',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ANNULLA'),
          ),
          FilledButton(
            onPressed: () {
              final ok = controller.text.trim() == 'KOL-TEST-2026';
              Navigator.pop(dialogContext, ok);
            },
            child: const Text('ATTIVA'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (confirmed != true || !context.mounted) {
      if (confirmed == false && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Codice tester non valido.')),
        );
      }
      return;
    }

    await storage.setSelectedPlan('TESTER');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('kingo_medico_free_answers_used', 0);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Modalità TESTER KOL attiva: chat illimitata.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () => _activateTester(context),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('KINGO Medico', style: TextStyle(fontWeight: FontWeight.w900)),
              Text(
                'Il tuo assistente sanitario AI in italiano',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF607985)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _open(context, const AccountPage()),
            icon: const Icon(Icons.person_outline),
            label: const Text('Accedi'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [KingoMedicoApp.primary, KingoMedicoApp.secondary],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 44),
                const SizedBox(height: 14),
                const Text(
                  'La tua salute, più semplice da capire.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Parla con KINGO, organizza visite e farmaci e conserva i tuoi referti.',
                  style: TextStyle(color: Colors.white, height: 1.4),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => _open(context, const MedicalChatPage()),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: KingoMedicoApp.primary,
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Parla con KINGO'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Come posso aiutarti oggi?',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.chat_bubble_outline,
            title: 'Parla con KINGO',
            subtitle: 'Sintomi, dubbi e orientamento',
            onTap: () => _open(context, const MedicalChatPage()),
          ),
          _ActionTile(
            icon: Icons.description_outlined,
            title: 'Esami e referti',
            subtitle: 'Salva PDF, foto e documenti',
            onTap: () => _open(context, const DocumentsPage()),
          ),
          _ActionTile(
            icon: Icons.calendar_month_outlined,
            title: 'Agenda Salute',
            subtitle: 'Visite con avviso il giorno prima',
            onTap: () => _open(context, const AgendaPage()),
          ),
          _ActionTile(
            icon: Icons.medication_outlined,
            title: 'Promemoria farmaci',
            subtitle: 'Avviso giornaliero con suono dedicato',
            onTap: () => _open(context, const MedicinesPage()),
          ),
          _ActionTile(
            icon: Icons.phone_in_talk_outlined,
            title: 'Numeri utili',
            subtitle: 'Tocca un numero per aprire il telefono',
            onTap: () => _open(context, const UsefulNumbersPage()),
          ),
          _ActionTile(
            icon: Icons.workspace_premium_outlined,
            title: 'Piani FREE, PLUS e PRO',
            subtitle: 'Scegli il piano più adatto',
            onTap: () => _open(context, const PlansPage()),
          ),
          const SizedBox(height: 16),
          const _SafetyCard(),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: KingoMedicoApp.soft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: KingoMedicoApp.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class MedicalChatPage extends StatefulWidget {
  const MedicalChatPage({super.key});

  @override
  State<MedicalChatPage> createState() => _MedicalChatPageState();
}

class _MedicalChatPageState extends State<MedicalChatPage> {
  static const int _freeLimit = 2;
  static const String _freeCountKey = 'kingo_medico_free_answers_used';

  final _service = MedicalAiService();
  final _storage = AppStorageService();
  final _controller = TextEditingController();

  final List<_ChatMessage> _messages = const [
    _ChatMessage(
      user: false,
      text:
          'Ciao, sono KINGO Medico. Posso aiutarti a capire meglio sintomi, esami e referti. Non sostituisco il medico.',
    ),
  ].toList();

  bool _sending = false;
  int _freeUsed = 0;
  String _plan = 'FREE';

  @override
  void initState() {
    super.initState();
    _loadPlanAndLimit();
  }

  Future<void> _loadPlanAndLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final plan = await _storage.getSelectedPlan();
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _freeUsed = prefs.getInt(_freeCountKey) ?? 0;
    });
  }

  int get _remaining => (_freeLimit - _freeUsed).clamp(0, _freeLimit);

  String _cleanAiText(String text) {
    return text
        .replaceAll('**', '')
        .replaceAll('__', '')
        .replaceAll(RegExp(r'(?m)^\s*[-•]\s+'), '• ');
  }

  Future<void> _showUpgrade() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                size: 42,
                color: KingoMedicoApp.primary,
              ),
              const SizedBox(height: 12),
              const Text(
                'Hai utilizzato le 2 risposte gratuite',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Per continuare a parlare con KINGO Medico scegli il piano PLUS o PRO.',
                style: TextStyle(fontSize: 16, height: 1.4),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PlansPage()),
                    );
                  },
                  child: const Text('VEDI PLUS E PRO'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('NON ORA'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    if (_plan == 'FREE' && _freeUsed >= _freeLimit) {
      await _showUpgrade();
      return;
    }

    final history = _messages
        .map((m) => {
              'role': m.user ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();

    setState(() {
      _messages.add(_ChatMessage(user: true, text: text));
      _controller.clear();
      _sending = true;
    });

    try {
      final reply = await _service.sendMessage(message: text, history: history);

      if (_plan == 'FREE') {
        final prefs = await SharedPreferences.getInstance();
        final newCount = (_freeUsed + 1).clamp(0, _freeLimit);
        await prefs.setInt(_freeCountKey, newCount);
        _freeUsed = newCount;
      }

      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(user: false, text: _cleanAiText(reply)),
        );
      });

      if (_plan == 'FREE' && _freeUsed >= _freeLimit) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (mounted) await _showUpgrade();
      }
    } on MedicalAiException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(user: false, text: _cleanAiText(e.message)),
        );
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final free = _plan == 'FREE';
    final tester = _plan == 'TESTER';

    return Scaffold(
      appBar: AppBar(title: const Text('Parla con KINGO')),
      body: Column(
        children: [
          if (tester)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7EE),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'TESTER KOL • risposte illimitate',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          if (free)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: KingoMedicoApp.soft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _remaining > 0
                    ? 'Piano FREE • $_remaining ${_remaining == 1 ? 'risposta rimasta' : 'risposte rimaste'}'
                    : 'Piano FREE • limite gratuito raggiunto',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                return Align(
                  alignment: m.user ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 330),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: m.user ? KingoMedicoApp.primary : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      m.text,
                      style: TextStyle(
                        color: m.user ? Colors.white : KingoMedicoApp.text,
                        height: 1.35,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_sending) const LinearProgressIndicator(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !(free && _freeUsed >= _freeLimit),
                      minLines: 1,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: free && _freeUsed >= _freeLimit
                            ? 'Scegli PLUS o PRO per continuare'
                            : 'Scrivi cosa vuoi capire...',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending
                        ? null
                        : (free && _freeUsed >= _freeLimit)
                            ? _showUpgrade
                            : _send,
                    icon: Icon(
                      free && _freeUsed >= _freeLimit
                          ? Icons.workspace_premium
                          : Icons.send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final bool user;
  final String text;
  const _ChatMessage({required this.user, required this.text});
}

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final _storage = AppStorageService();
  List<Map<String, dynamic>> _documents = [];
  PlatformFile? _pending;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final data = await _storage.loadDocuments();
    if (mounted) setState(() => _documents = data);
  }

  Future<void> _choose() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _pending = result.files.first);
  }

  Future<void> _savePending() async {
    final file = _pending;
    if (file == null || file.path == null) {
      _snack('Seleziona prima un documento.');
      return;
    }

    try {
      final archivedPath = await _storage.archiveFile(file.path!, file.name);
      _documents.add({
        'name': file.name,
        'path': archivedPath,
        'date': DateTime.now().toIso8601String(),
      });
      await _storage.saveDocuments(_documents);
      if (!mounted) return;
      setState(() => _pending = null);
      _snack('Documento salvato nel tuo archivio.');
    } catch (_) {
      _snack('Non è stato possibile salvare il documento.');
    }
  }

  Future<void> _delete(int index) async {
    final item = _documents[index];
    await _storage.deleteArchivedFile(item['path']?.toString() ?? '');
    _documents.removeAt(index);
    await _storage.saveDocuments(_documents);
    if (mounted) setState(() {});
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Esami e referti')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _choose,
            icon: const Icon(Icons.upload_file),
            label: const Text('Scegli un esame o referto'),
          ),
          if (_pending != null) ...[
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(_pending!.name),
                subtitle: const Text('Pronto per essere salvato'),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _savePending,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Salva nel mio archivio'),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'I miei documenti',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (_documents.isEmpty)
            const Text('Nessun documento salvato.')
          else
            ...List.generate(_documents.length, (i) {
              final item = _documents[i];
              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.folder_copy_outlined,
                    color: KingoMedicoApp.primary,
                  ),
                  title: Text(item['name']?.toString() ?? 'Documento'),
                  subtitle: const Text('Salvato sul dispositivo'),
                  trailing: IconButton(
                    onPressed: () => _delete(i),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              );
            }),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pending == null ? null : () => _snack('Documento pronto.'),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Invia a KINGO per spiegazione'),
          ),
        ],
      ),
    );
  }
}

class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  final _storage = AppStorageService();
  List<Map<String, dynamic>> _appointments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _storage.loadAppointments();
    if (mounted) setState(() => _appointments = data);
  }

  Future<void> _add() async {
    final result = await Navigator.push<_AppointmentDraft>(
      context,
      MaterialPageRoute(builder: (_) => const AppointmentEditorPage()),
    );
    if (result == null) return;

    final id = DateTime.now().millisecondsSinceEpoch.remainder(2000000000);
    _appointments.add({
      'id': id,
      'title': result.title,
      'date': result.dateTime.toIso8601String(),
    });
    await _storage.saveAppointments(_appointments);
    await NotificationService.instance.scheduleAppointmentReminder(
      id: id,
      title: result.title,
      appointment: result.dateTime,
    );
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Appuntamento salvato.')),
    );
  }

  Future<void> _delete(int index) async {
    final id = (_appointments[index]['id'] as num?)?.toInt();
    if (id != null) await NotificationService.instance.cancel(id);
    _appointments.removeAt(index);
    await _storage.saveAppointments(_appointments);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agenda Salute')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Nuova visita'),
      ),
      body: _appointments.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Text(
                  'Nessun appuntamento.\nPremi “Nuova visita” per inserirne uno.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _appointments.length,
              itemBuilder: (_, i) {
                final item = _appointments[i];
                final dt = DateTime.tryParse(item['date']?.toString() ?? '');
                return Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.event_available,
                      color: KingoMedicoApp.primary,
                    ),
                    title: Text(item['title']?.toString() ?? 'Visita'),
                    subtitle: Text(dt == null ? '' : _formatDateTime(dt)),
                    trailing: IconButton(
                      onPressed: () => _delete(i),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class AppointmentEditorPage extends StatefulWidget {
  const AppointmentEditorPage({super.key});

  @override
  State<AppointmentEditorPage> createState() => _AppointmentEditorPageState();
}

class _AppointmentEditorPageState extends State<AppointmentEditorPage> {
  final _title = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci il tipo di visita o lo specialista.')),
      );
      return;
    }
    Navigator.pop(
      context,
      _AppointmentDraft(
        title,
        DateTime(
          _date.year,
          _date.month,
          _date.day,
          _time.hour,
          _time.minute,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuova visita')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Visita / specialista',
              hintText: 'Es. Dentista',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: Text('${_date.day}/${_date.month}/${_date.year}'),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
                initialDate: _date,
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(_time.format(context)),
            onTap: () async {
              final picked = await showTimePicker(context: context, initialTime: _time);
              if (picked != null) setState(() => _time = picked);
            },
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Salva appuntamento'),
          ),
        ],
      ),
    );
  }
}

class _AppointmentDraft {
  final String title;
  final DateTime dateTime;
  const _AppointmentDraft(this.title, this.dateTime);
}

class MedicinesPage extends StatefulWidget {
  const MedicinesPage({super.key});

  @override
  State<MedicinesPage> createState() => _MedicinesPageState();
}

class _MedicinesPageState extends State<MedicinesPage> {
  final _storage = AppStorageService();
  List<Map<String, dynamic>> _medicines = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _storage.loadMedicines();
    if (mounted) setState(() => _medicines = data);
  }

  Future<void> _add() async {
    final result = await Navigator.push<_MedicineDraft>(
      context,
      MaterialPageRoute(builder: (_) => const MedicineEditorPage()),
    );
    if (result == null) return;

    final id = DateTime.now().millisecondsSinceEpoch.remainder(2000000000);
    _medicines.add({
      'id': id,
      'name': result.name,
      'hour': result.hour,
      'minute': result.minute,
    });
    await _storage.saveMedicines(_medicines);
    await NotificationService.instance.scheduleDailyMedicine(
      id: id,
      medicine: result.name,
      hour: result.hour,
      minute: result.minute,
    );
    if (mounted) setState(() {});
  }

  Future<void> _edit(int index) async {
    final m = _medicines[index];
    final id = (m['id'] as num?)?.toInt();
    final initial = _MedicineDraft(
      m['name']?.toString() ?? '',
      (m['hour'] as num?)?.toInt() ?? 8,
      (m['minute'] as num?)?.toInt() ?? 0,
    );

    final result = await Navigator.push<_MedicineDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => MedicineEditorPage(initial: initial),
      ),
    );
    if (result == null) return;

    if (id != null) await NotificationService.instance.cancel(id);

    _medicines[index] = {
      'id': id ?? DateTime.now().millisecondsSinceEpoch.remainder(2000000000),
      'name': result.name,
      'hour': result.hour,
      'minute': result.minute,
    };

    await _storage.saveMedicines(_medicines);

    final newId = (_medicines[index]['id'] as num).toInt();
    await NotificationService.instance.scheduleDailyMedicine(
      id: newId,
      medicine: result.name,
      hour: result.hour,
      minute: result.minute,
    );

    if (mounted) setState(() {});
  }

  Future<void> _delete(int index) async {
    final id = (_medicines[index]['id'] as num?)?.toInt();
    if (id != null) await NotificationService.instance.cancel(id);
    _medicines.removeAt(index);
    await _storage.saveMedicines(_medicines);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Promemoria farmaci')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Aggiungi'),
      ),
      body: _medicines.isEmpty
          ? const Center(child: Text('Nessun promemoria farmaco impostato.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _medicines.length,
              itemBuilder: (_, i) {
                final m = _medicines[i];
                final hour = (m['hour'] as num?)?.toInt() ?? 0;
                final minute = (m['minute'] as num?)?.toInt() ?? 0;
                return Card(
                  child: ListTile(
                    onTap: () => _edit(i),
                    leading: const Icon(
                      Icons.medication,
                      color: KingoMedicoApp.primary,
                    ),
                    title: Text(m['name']?.toString() ?? 'Farmaco'),
                    subtitle: Text(
                      'Ogni giorno alle ${hour.toString().padLeft(2, '0')}:'
                      '${minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: Wrap(
                      spacing: 0,
                      children: [
                        IconButton(
                          tooltip: 'Modifica',
                          onPressed: () => _edit(i),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Elimina',
                          onPressed: () => _delete(i),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class MedicineEditorPage extends StatefulWidget {
  final _MedicineDraft? initial;
  const MedicineEditorPage({super.key, this.initial});

  @override
  State<MedicineEditorPage> createState() => _MedicineEditorPageState();
}

class _MedicineEditorPageState extends State<MedicineEditorPage> {
  late final TextEditingController _name;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _time = TimeOfDay(
      hour: widget.initial?.hour ?? 8,
      minute: widget.initial?.minute ?? 0,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci il nome del farmaco.')),
      );
      return;
    }
    Navigator.pop(
      context,
      _MedicineDraft(name, _time.hour, _time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Modifica promemoria' : 'Nuovo promemoria'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Farmaco / integratore',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(_time.format(context)),
            onTap: () async {
              final picked = await showTimePicker(context: context, initialTime: _time);
              if (picked != null) setState(() => _time = picked);
            },
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.notifications_active),
            label: Text(
              editing ? 'Salva modifiche' : 'Salva e attiva promemoria',
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicineDraft {
  final String name;
  final int hour;
  final int minute;
  const _MedicineDraft(this.name, this.hour, this.minute);
}

class UsefulNumbersPage extends StatelessWidget {
  const UsefulNumbersPage({super.key});

  Future<void> _call(BuildContext context, String number) async {
    final uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile aprire il telefono.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const numbers = [
      ('Numero unico emergenze', '112'),
      ('Emergenza sanitaria', '118'),
      ('Polizia di Stato', '113'),
      ('Vigili del Fuoco', '115'),
      ('Guardia di Finanza', '117'),
      ('Telefono Azzurro', '19696'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Numeri utili')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...numbers.map(
            (item) => Card(
              child: ListTile(
                leading: const Icon(
                  Icons.phone_in_talk,
                  color: KingoMedicoApp.primary,
                ),
                title: Text(item.$1),
                subtitle: Text(item.$2),
                trailing: const Icon(Icons.phone),
                onTap: () => _call(context, item.$2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'I numeri territoriali verranno inseriti dopo verifica ufficiale per area geografica.',
            style: TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class PlansPage extends StatefulWidget {
  const PlansPage({super.key});

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  final _storage = AppStorageService();
  String selected = 'FREE';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    selected = await _storage.getSelectedPlan();
    if (mounted) setState(() {});
  }

  Future<void> _choose(String plan) async {
    if (plan == 'FREE') {
      await _storage.setSelectedPlan(plan);
      if (mounted) setState(() => selected = plan);
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Piano $plan'),
        content: const Text(
          'Il piano sarà attivabile tramite Google Play nella versione di pubblicazione.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Piani KINGO Medico')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PlanCard(
            title: 'FREE',
            price: 'Gratis',
            features: const [
              '2 risposte gratuite',
              '1 esame o referto',
              'Avvisi di sicurezza sempre disponibili',
            ],
            selected: selected == 'FREE',
            button: 'PIANO ATTUALE',
            onTap: () => _choose('FREE'),
          ),
          _PlanCard(
            title: 'PLUS',
            price: 'Prezzo da definire / mese',
            features: const [
              'Più consultazioni',
              'Più documenti',
              'Cronologia',
              'Agenda Salute',
            ],
            selected: selected == 'PLUS',
            button: 'SCEGLI PLUS',
            onTap: () => _choose('PLUS'),
          ),
          _PlanCard(
            title: 'PRO',
            price: 'Prezzo da definire / mese',
            features: const [
              'Analisi avanzata documenti',
              'Riepilogo per il medico',
              'Preparazione visita',
              'Funzioni avanzate',
            ],
            selected: selected == 'PRO',
            button: 'SCEGLI PRO',
            onTap: () => _choose('PRO'),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final List<String> features;
  final bool selected;
  final String button;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.features,
    required this.selected,
    required this.button,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                if (selected) const Chip(label: Text('ATTIVO')),
              ],
            ),
            Text(
              price,
              style: const TextStyle(
                color: KingoMedicoApp.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 19),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onTap,
                child: Text(button),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            onLongPress: () async {
              final storage = AppStorageService();
              final current = await storage.getSelectedPlan();
              if (current == 'TESTER') {
                await storage.setSelectedPlan('FREE');
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('kingo_medico_free_answers_used', 0);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Modalità TESTER disattivata. Piano FREE ripristinato.'),
                    ),
                  );
                }
              }
            },
            child: const Text('Account KINGO Medico'),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'ACCEDI'),
              Tab(text: 'ISCRIVITI'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AccountForm(register: false),
            _AccountForm(register: true),
          ],
        ),
      ),
    );
  }
}

class _AccountForm extends StatefulWidget {
  final bool register;
  const _AccountForm({required this.register});

  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  final email = TextEditingController();
  final password = TextEditingController();

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 12),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: password,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  widget.register
                      ? 'Registrazione non ancora attiva.'
                      : 'Accesso non ancora attivo.',
                ),
              ),
            );
          },
          child: Text(widget.register ? 'ISCRIVITI' : 'ACCEDI'),
        ),
      ],
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'KINGO Medico fornisce informazioni e orientamento sanitario. Non sostituisce il medico, non effettua diagnosi definitive e non prescrive terapie. In caso di emergenza contatta i servizi sanitari.',
        style: TextStyle(height: 1.4),
      ),
    );
  }
}

String _formatDateTime(DateTime dt) {
  return '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/${dt.year} · '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}
