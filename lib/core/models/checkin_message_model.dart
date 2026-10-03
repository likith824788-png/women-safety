class CheckinMessage {
  final String id;
  final String text;
  final String? audioRef;
  final DateTime createdAt;
  final double riskScore;
  final String action; // "no_action" | "show_countdown" | "auto_escalate"
  final bool isUserMessage;

  CheckinMessage({
    required this.id,
    required this.text,
    this.audioRef,
    required this.createdAt,
    required this.riskScore,
    required this.action,
    this.isUserMessage = true,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'audioRef': audioRef,
      'createdAt': createdAt.toIso8601String(),
      'riskScore': riskScore,
      'action': action,
      'isUserMessage': isUserMessage,
    };
  }

  factory CheckinMessage.fromFirestore(Map<String, dynamic> data, String docId) {
    return CheckinMessage(
      id: docId,
      text: data['text'] ?? '',
      audioRef: data['audioRef'],
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      riskScore: (data['riskScore'] as num?)?.toDouble() ?? 0.0,
      action: data['action'] ?? 'no_action',
      isUserMessage: data['isUserMessage'] ?? true,
    );
  }
}
