import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../core/providers/sos_provider.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/ai_checkin/services/voice_command_handler.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_drawer.dart';

class AiCheckinMessage {
  final String text;
  final bool isUser;
  final GemmaIntent? intent;
  final DateTime timestamp;

  AiCheckinMessage({
    required this.text,
    required this.isUser,
    this.intent,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class AiCheckinScreen extends ConsumerStatefulWidget {
  final Function(int) onNavigateTab;
  final VoidCallback? onBack;

  const AiCheckinScreen({
    super.key,
    required this.onNavigateTab,
    this.onBack,
  });

  @override
  ConsumerState<AiCheckinScreen> createState() => _AiCheckinScreenState();
}

class _AiCheckinScreenState extends ConsumerState<AiCheckinScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<AiCheckinMessage> _messages = [];
  bool _isProcessing = false;

  // Voice
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  Timer? _speechTimeout;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _purgeOldMessagesAndAddWelcome();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _speechTimeout?.cancel();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (e) => debugPrint('Speech error: $e'),
    );
    setState(() {});
  }

  void _purgeOldMessagesAndAddWelcome() {
    final now = DateTime.now();
    // Keep only messages from the last 24 hours
    _messages.removeWhere((m) => now.difference(m.timestamp).inHours >= 24);

    if (_messages.isEmpty) {
      _messages.add(AiCheckinMessage(
        text: 'Hi! I\'m your Aegis AI Safety Assistant. How can I help you today?',
        isUser: false,
      ));
    }
  }


  Future<void> _processMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(AiCheckinMessage(text: text, isUser: true));
      _isProcessing = true;
      _msgCtrl.clear();
    });
    _scrollToBottom();

    // Analyze input via Gemini AI Service
    final response = await GeminiService.analyzeMessage(text);

    if (!mounted) return;

    final isDanger = response.isDanger ||
        response.intent == GemmaIntent.danger ||
        response.dangerScore >= 0.5;

    final handler = VoiceCommandHandler(
      context: context,
      onOpenCompanion: () => widget.onNavigateTab(2),
      onOpenCompanionWithLocation: (location) {
        widget.onNavigateTab(2);
      },
      onOpenLiveShare: () => widget.onNavigateTab(1),
      onOpenEmergency: () => widget.onNavigateTab(4),
      onTriggerSos: () {
        ref.read(sosProvider.notifier).startSosCountdown(
              triggerSource: 'ai_assistant',
              seconds: 10,
            );
      },
    );

    if (isDanger) {
      // DANGER DETECTED → Activate SOS, record audio & notify CNN model
      ref.read(sosProvider.notifier).startSosCountdown(
            triggerSource: 'ai_assistant',
            seconds: 10,
          );

      setState(() {
        _messages.add(AiCheckinMessage(
          text:
              '🚨 EMERGENCY DETECTED!\n\nActivating Emergency SOS countdown, recording 5s ambient audio, and feeding to CNN model for threat risk assessment.',
          isUser: false,
          intent: GemmaIntent.danger,
        ));
        _isProcessing = false;
      });
    } else {
      // NORMAL INPUT → React like a friendly safety chatbot
      setState(() {
        _messages.add(AiCheckinMessage(
          text: response.reply,
          isUser: false,
          intent: response.intent,
        ));
        _isProcessing = false;
      });
      handler.executeIntent(response);
    }

    _scrollToBottom();
  }

  Future<void> _start5SecVoiceListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Speech recognition not available on this device.')),
      );
      return;
    }

    setState(() => _isListening = true);

    // Auto-stop after 5 seconds
    _speechTimeout?.cancel();
    _speechTimeout = Timer(const Duration(seconds: 5), () {
      if (_isListening) {
        _stopListening();
      }
    });

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          _speechTimeout?.cancel();
          setState(() => _isListening = false);
          _processMessage(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 5),
      pauseFor: const Duration(seconds: 2),
      cancelOnError: true,
    );
  }

  void _stopListening() {
    _speechTimeout?.cancel();
    _speech.stop();
    setState(() => _isListening = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      drawer: AppDrawer(
        currentIndex: 3,
        onNavigate: widget.onNavigateTab,
      ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            tooltip: 'Open navigation sidebar',
          ),
        ),
        title: const Text('AI Safety Assistant'),
      ),

      body: Column(
        children: [
          // Voice listening banner indicator
          if (_isListening)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: AppColors.sosRed.withOpacity(0.12),
              child: const Row(
                children: [
                  Icon(Icons.record_voice_over, color: AppColors.sosRed, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Listening (5 seconds max)... Speak now!',
                    style: TextStyle(
                      color: AppColors.sosRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isProcessing ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length) {
                  return _typingBubble();
                }
                final msg = _messages[i];
                return _messageBubble(msg);
              },
            ),
          ),

          // Unified Input Area (Mic + Text + Send)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Bottom-left Speech Icon (5s voice recording)
                GestureDetector(
                  onTap:
                      _isListening ? _stopListening : _start5SecVoiceListening,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isListening
                          ? AppColors.sosRed
                          : AppColors.primaryNavy,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isListening ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Center Text Input
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    onSubmitted: _processMessage,
                    decoration: InputDecoration(
                      hintText: _isListening
                          ? 'Listening (5s max)...'
                          : 'Type or tap mic to speak...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24)),
                      filled: true,
                      fillColor: AppColors.backgroundLight,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Bottom-right Send Icon
                GestureDetector(
                  onTap: () => _processMessage(_msgCtrl.text),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryNavy,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(AiCheckinMessage msg) {
    final isUser = msg.isUser;

    IconData? intentIcon;
    Color? intentColor;
    if (!isUser && msg.intent != null) {
      switch (msg.intent!) {
        case GemmaIntent.danger:
          intentIcon = Icons.warning;
          intentColor = AppColors.sosRed;
          break;
        case GemmaIntent.openCompanion:
          intentIcon = Icons.navigation;
          intentColor = const Color(0xFF0284C7);
          break;
        case GemmaIntent.openLiveShare:
          intentIcon = Icons.share_location;
          intentColor = AppColors.safeGreen;
          break;
        default:
          intentIcon = null;
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 60 : 0,
        right: isUser ? 0 : 60,
        bottom: 12,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.primaryNavy,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.psychology, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primaryNavy : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (intentIcon != null) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(intentIcon, color: intentColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          msg.intent
                              .toString()
                              .split('.')
                              .last
                              .toUpperCase()
                              .replaceAll('_', ' '),
                          style: TextStyle(
                            color: intentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    msg.text,
                    style: TextStyle(
                      color: isUser ? Colors.white : AppColors.textDark,
                      fontSize: 15,
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

  Widget _typingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: AppColors.primaryNavy,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                ),
              ],
            ),
            child: const Row(
              children: [
                _Dot(delay: 0),
                SizedBox(width: 4),
                _Dot(delay: 200),
                SizedBox(width: 4),
                _Dot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween(begin: 0.4, end: 1.0).animate(_ctrl);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child:
          const CircleAvatar(radius: 4, backgroundColor: AppColors.primaryNavy),
    );
  }
}
