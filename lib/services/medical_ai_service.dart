import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class MedicalAiService {
  static const String _endpoint =
      'https://www.kingofline.it/wp-json/kingo-medico/v1/chat';
  static const Duration _timeout = Duration(seconds: 25);

  Future<String> sendMessage({
    required String message,
    List<Map<String, String>> history = const [],
  }) async {
    final clean = message.trim();
    if (clean.isEmpty) {
      throw const MedicalAiException('Scrivi un messaggio prima di inviare.');
    }

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'message': clean,
              'history': history,
              'language': 'it',
            }),
          )
          .timeout(_timeout);

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map) {
          final reply = decoded['reply'] ?? decoded['message'];
          if (reply is String && reply.trim().isNotEmpty) {
            return reply.trim();
          }
        }
        throw const MedicalAiException(
          'Il server ha risposto, ma KINGO non ha ricevuto un testo valido.',
        );
      }

      if (decoded is Map && decoded['message'] is String) {
        throw MedicalAiException(decoded['message'].toString());
      }

      throw MedicalAiException(
        'Servizio KINGO temporaneamente non disponibile (${response.statusCode}).',
      );
    } on TimeoutException {
      throw const MedicalAiException(
        'KINGO non ha ricevuto risposta dal server entro 25 secondi. Riprova.',
      );
    } on MedicalAiException {
      rethrow;
    } catch (e) {
      throw MedicalAiException(
        'Impossibile collegarsi a KINGO in questo momento. Dettaglio: ${e.runtimeType}.',
      );
    }
  }
}

class MedicalAiException implements Exception {
  final String message;
  const MedicalAiException(this.message);

  @override
  String toString() => message;
}
