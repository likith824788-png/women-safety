import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'nlp_risk_engine.dart';

enum GemmaIntent {
  openCompanion,
  openLiveShare,
  openEmergency,
  callEmergency,
  danger,
  safe,
  chat,
}

class GemmaResponse {
  final GemmaIntent intent;
  final String reply;
  final String? location;
  final bool isDanger;
  final double dangerScore;

  GemmaResponse({
    required this.intent,
    required this.reply,
    this.location,
    this.isDanger = false,
    this.dangerScore = 0.0,
  });
}

class GeminiService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String _model = 'gemma-3-12b-it';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static const String _systemPrompt = '''
You are a safety AI assistant for the Aegis Safety app. Analyze the user's message and respond with ONLY a valid JSON object.

JSON format:
{
  "intent": "<one of: open_companion, open_live_share, open_emergency, danger, safe, chat>",
  "reply": "<your warm, natural response to the user>",
  "location": "<destination if intent is open_companion, else null>",
  "is_danger": <true or false>,
  "danger_score": <float 0.0 to 1.0>
}
''';

  /// Analyzes the message using the Pre-trained AI NLP Model Engine & Generative AI
  static Future<GemmaResponse> analyzeMessage(String userMessage) async {
    // 1. First run high-speed Pre-trained NLP Risk Model Engine
    final nlpResult = NlpRiskEngine.analyze(userMessage);

    // If NLP model flags explicit danger or high-priority intent, return immediately for instant real-time safety response!
    if (nlpResult.isEmergency || nlpResult.riskScore >= 0.50 || nlpResult.intent != 'chat') {
      return _mapNlpToGemmaResponse(nlpResult);
    }

    // 2. Otherwise attempt cloud Gemini generative endpoint (with fallback to NLP Risk Model)
    try {
      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': '$_systemPrompt\n\nUser message: "$userMessage"'},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 256,
        },
      };

      final uri = Uri.parse('$_baseUrl?key=$_apiKey');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        return _parseResponse(text, userMessage, nlpResult);
      } else {
        return _mapNlpToGemmaResponse(nlpResult);
      }
    } catch (e) {
      debugPrint('Gemini API call timed out or failed: $e — using Pre-trained NLP Risk Model');
      return _mapNlpToGemmaResponse(nlpResult);
    }
  }

  static GemmaResponse _mapNlpToGemmaResponse(NlpRiskResult nlp) {
    GemmaIntent intent = GemmaIntent.chat;
    switch (nlp.intent) {
      case 'open_companion':
        intent = GemmaIntent.openCompanion;
        break;
      case 'open_live_share':
        intent = GemmaIntent.openLiveShare;
        break;
      case 'open_emergency':
        intent = GemmaIntent.openEmergency;
        break;
      case 'danger':
        intent = GemmaIntent.danger;
        break;
      case 'safe':
        intent = GemmaIntent.safe;
        break;
      default:
        intent = GemmaIntent.chat;
    }

    return GemmaResponse(
      intent: intent,
      reply: nlp.reply,
      location: nlp.extractedLocation,
      isDanger: nlp.isEmergency || nlp.riskScore >= 0.50,
      dangerScore: nlp.riskScore,
    );
  }

  static GemmaResponse _parseResponse(String text, String originalMessage, NlpRiskResult fallbackNlp) {
    try {
      String jsonStr = text.trim();
      if (jsonStr.contains('```')) {
        final start = jsonStr.indexOf('{');
        final end = jsonStr.lastIndexOf('}') + 1;
        if (start >= 0 && end > start) {
          jsonStr = jsonStr.substring(start, end);
        }
      }

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      GemmaIntent intent = GemmaIntent.chat;
      switch (data['intent'] as String? ?? 'chat') {
        case 'open_companion':
          intent = GemmaIntent.openCompanion;
          break;
        case 'open_live_share':
          intent = GemmaIntent.openLiveShare;
          break;
        case 'open_emergency':
          intent = GemmaIntent.openEmergency;
          break;
        case 'danger':
          intent = GemmaIntent.danger;
          break;
        case 'safe':
          intent = GemmaIntent.safe;
          break;
        default:
          intent = GemmaIntent.chat;
      }

      final replyText = data['reply'] as String? ?? fallbackNlp.reply;

      return GemmaResponse(
        intent: intent,
        reply: replyText.isNotEmpty ? replyText : fallbackNlp.reply,
        location: data['location'] as String? ?? fallbackNlp.extractedLocation,
        isDanger: data['is_danger'] as bool? ?? fallbackNlp.isEmergency,
        dangerScore: (data['danger_score'] as num?)?.toDouble() ?? fallbackNlp.riskScore,
      );
    } catch (e) {
      debugPrint('Parse error: $e — using NLP model fallback');
      return _mapNlpToGemmaResponse(fallbackNlp);
    }
  }
}
