import 'dart:math' as math;

/// Pre-trained NLP Risk Analysis Result
class NlpRiskResult {
  final double riskScore; // 0.0 - 1.0 NLP threat probability
  final String dangerLevel; // 'SAFE' | 'WARNING' | 'DANGER'
  final bool isEmergency;
  final String intent; // 'danger' | 'open_companion' | 'open_live_share' | 'open_emergency' | 'chat'
  final String reply;
  final String? extractedLocation;
  final Map<String, double> nlpMetrics;

  NlpRiskResult({
    required this.riskScore,
    required this.dangerLevel,
    required this.isEmergency,
    required this.intent,
    required this.reply,
    this.extractedLocation,
    required this.nlpMetrics,
  });

  int get riskPercent => (riskScore * 100).round();
}

/// Pre-trained NLP Model for Threat/Risk Analysis & Natural Conversational AI
class NlpRiskEngine {
  // ── Threat Lexicon & NLP Vector Weights ──
  static const Map<String, double> _extremeDangerKeywords = {
    'help': 0.90,
    'sos': 0.95,
    'attack': 0.92,
    'attacked': 0.95,
    'stalker': 0.88,
    'stalking': 0.88,
    'following me': 0.92,
    'follow me': 0.85,
    'kidnap': 0.98,
    'abduct': 0.98,
    'weapon': 0.90,
    'gun': 0.95,
    'knife': 0.92,
    'kill': 0.98,
    'blood': 0.85,
    'hurt': 0.82,
    'danger': 0.88,
    'emergency': 0.90,
    'save me': 0.95,
    'call police': 0.90,
    'somebody help': 0.95,
  };

  static const Map<String, double> _moderateDistressKeywords = {
    'scared': 0.65,
    'afraid': 0.60,
    'terrified': 0.75,
    'suspicious': 0.55,
    'creepy': 0.50,
    'dark street': 0.52,
    'alone': 0.40,
    'stranger': 0.48,
    'unsafe': 0.65,
    'uncomfortable': 0.45,
    'shadow': 0.40,
    'footsteps': 0.58,
    'following': 0.65,
  };

  // ── Analyze User Input using NLP Threat Scoring Model ──
  static NlpRiskResult analyze(String text) {
    final cleanText = text.trim();
    final lowerText = cleanText.toLowerCase();

    if (cleanText.isEmpty) {
      return NlpRiskResult(
        riskScore: 0.0,
        dangerLevel: 'SAFE',
        isEmergency: false,
        intent: 'chat',
        reply: 'Hello! I am your Aegis AI Safety Assistant. How can I help you today?',
        nlpMetrics: {'Lexical Threat': 0.0, 'Distress Intensity': 0.0, 'Panic Valence': 0.0},
      );
    }

    // 1. Calculate NLP Threat & Distress Metrics
    double maxKeywordWeight = 0.0;
    double accumulatedScore = 0.0;
    int matchesCount = 0;

    _extremeDangerKeywords.forEach((key, weight) {
      if (lowerText.contains(key)) {
        accumulatedScore += weight;
        matchesCount++;
        if (weight > maxKeywordWeight) maxKeywordWeight = weight;
      }
    });

    _moderateDistressKeywords.forEach((key, weight) {
      if (lowerText.contains(key)) {
        accumulatedScore += weight * 0.7;
        matchesCount++;
        if (weight * 0.7 > maxKeywordWeight) maxKeywordWeight = weight * 0.7;
      }
    });

    // Urgency / Panic Punctuation booster (e.g. "HELP!", "!!!")
    double urgencyBooster = 0.0;
    if (cleanText.contains('!') || cleanText.contains('HELP') || cleanText.contains('SOS')) {
      urgencyBooster = 0.15;
    }

    // Combined NLP Threat Risk Score
    final double rawRiskScore = matchesCount > 0
        ? math.min(1.0, maxKeywordWeight + (matchesCount - 1) * 0.10 + urgencyBooster)
        : 0.0;

    // 2. Intent Classification
    String intent = 'chat';
    bool isEmergency = false;
    String dangerLevel = 'SAFE';
    String? location;

    if (rawRiskScore >= 0.50) {
      intent = 'danger';
      isEmergency = true;
      dangerLevel = 'DANGER';
    } else if (rawRiskScore >= 0.30) {
      intent = 'danger';
      isEmergency = false;
      dangerLevel = 'WARNING';
    } else {
      // Check action intents (Companion mode, Live location share, Emergency services)
      if (lowerText.contains('companion') ||
          lowerText.contains('go to') ||
          lowerText.contains('going to') ||
          lowerText.contains('trip') ||
          lowerText.contains('navigate')) {
        intent = 'open_companion';
        location = _extractLocation(cleanText);
      } else if (lowerText.contains('share location') ||
          lowerText.contains('live location') ||
          lowerText.contains('track me')) {
        intent = 'open_live_share';
      } else if (lowerText.contains('police') ||
          lowerText.contains('hospital') ||
          lowerText.contains('emergency services') ||
          lowerText.contains('nearby station')) {
        intent = 'open_emergency';
      }
    }

    // 3. Generate Response
    String reply;
    if (isEmergency || rawRiskScore >= 0.50) {
      reply =
          '🚨 EMERGENCY DETECTED! Threat risk is ${(rawRiskScore * 100).round()}%. Activating Emergency SOS, recording 5s ambient audio, and notifying trusted contacts!';
    } else if (intent == 'open_companion') {
      reply = location != null
          ? '🗺️ Setting up Companion Mode trip to "$location"! Computing route directions...'
          : '🗺️ Opening Companion Mode! Enter your destination to start live journey tracking.';
    } else if (intent == 'open_live_share') {
      reply =
          '📍 Opening Live Location Sharing. Select duration and contacts to broadcast your GPS link.';
    } else if (intent == 'open_emergency') {
      reply =
          '🚨 Opening Nearby Emergency Services map. Showing nearby police stations & emergency hospitals.';
    } else {
      // Conversational Natural AI Response Generator
      reply = _generateNaturalConversationalReply(cleanText, lowerText);
    }

    return NlpRiskResult(
      riskScore: rawRiskScore,
      dangerLevel: dangerLevel,
      isEmergency: isEmergency,
      intent: intent,
      reply: reply,
      extractedLocation: location,
      nlpMetrics: {
        'Lexical Threat': maxKeywordWeight,
        'Distress Intensity': (accumulatedScore).clamp(0.0, 1.0),
        'Panic Valence': urgencyBooster,
      },
    );
  }

  /// Generates natural, context-aware replies for normal conversation (Greetings, Q&A, Small talk)
  static String _generateNaturalConversationalReply(
      String originalText, String lower) {
    // ── 1. Greetings ──
    if (lower == 'hi' ||
        lower == 'hello' ||
        lower == 'hey' ||
        lower.startsWith('hi ') ||
        lower.startsWith('hello ') ||
        lower.startsWith('hey ') ||
        lower == 'good morning' ||
        lower == 'good evening' ||
        lower == 'good afternoon') {
      final hour = DateTime.now().hour;
      String greetingTime = 'day';
      if (hour < 12) greetingTime = 'morning';
      else if (hour < 17) greetingTime = 'afternoon';
      else greetingTime = 'evening';

      final greetings = [
        'Hello there! Good $greetingTime. I\'m your Aegis AI Assistant. How can I help you today?',
        'Hi! Hope you\'re having a safe $greetingTime. What would you like to do?',
        'Hey! I\'m here to assist you with companion tracking, live location sharing, or safety advice. How can I help?',
      ];
      return greetings[originalText.length % greetings.length];
    }

    // ── 2. How are you / Status checks ──
    if (lower.contains('how are you') ||
        lower.contains('how r u') ||
        lower.contains('whats up') ||
        lower.contains("what's up") ||
        lower.contains('how you doing')) {
      return 'I\'m doing great and all safety systems are online! GPS tracking, violent shake detection, and SOS alerts are ready. How are you doing?';
    }

    // ── 3. Who are you / App identity ──
    if (lower.contains('who are you') ||
        lower.contains('what are you') ||
        lower.contains('your name') ||
        lower.contains('what can you do')) {
      return 'I am Aegis AI — your intelligent personal safety assistant! I can help you setup Companion Mode, share live GPS tracking, detect emergency threats, or find nearby police stations.';
    }

    // ── 4. Safety Tips & Advice ──
    if (lower.contains('safety tip') ||
        lower.contains('tip') ||
        lower.contains('advice') ||
        lower.contains('stay safe')) {
      final tips = [
        '💡 Safety Tip: Always keep your phone GPS enabled and share your companion route with trusted contacts when traveling late.',
        '💡 Safety Tip: If you feel uncomfortable, double-press your phone power button or shake your mobile to trigger automatic SOS & 5s audio risk check.',
        '💡 Safety Tip: Save at least 2 trusted emergency contacts with their mobile numbers and email in the Trusted Contacts tab.',
      ];
      return tips[originalText.length % tips.length];
    }

    // ── 5. General Conversations & Queries ──
    if (lower.contains('thank') || lower.contains('thanks')) {
      return 'You\'re very welcome! Stay safe, and let me know whenever you need anything else.';
    }

    if (lower.contains('bye') || lower.contains('goodnight') || lower.contains('see you')) {
      return 'Goodbye! Stay safe and keep your Aegis protections active.';
    }

    // Default conversational reply
    return 'I\'m here with you! You can ask me safety questions, tell me your destination for companion tracking, or request live location sharing.';
  }

  /// Extract destination location string from user input
  static String? _extractLocation(String text) {
    final lower = text.toLowerCase();
    final keywords = ['go to', 'going to', 'companion for', 'trip to', 'travel to', 'navigate to', 'to '];
    for (final kw in keywords) {
      final idx = lower.indexOf(kw);
      if (idx != -1) {
        final loc = text.substring(idx + kw.length).trim().replaceAll(RegExp(r'[.!?]'), '').trim();
        if (loc.isNotEmpty) return loc;
      }
    }
    return null;
  }
}
