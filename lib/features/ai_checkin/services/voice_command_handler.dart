import 'package:flutter/material.dart';
import '../../../core/services/gemini_service.dart';

/// Handles voice command execution based on Gemma AI parsed intents.
/// Takes a GemmaResponse and triggers the appropriate app navigation or action.
class VoiceCommandHandler {
  final BuildContext context;
  final VoidCallback? onOpenCompanion;
  final Function(String location)? onOpenCompanionWithLocation;
  final VoidCallback? onOpenLiveShare;
  final VoidCallback? onOpenEmergency;
  final VoidCallback? onTriggerSos;

  VoiceCommandHandler({
    required this.context,
    this.onOpenCompanion,
    this.onOpenCompanionWithLocation,
    this.onOpenLiveShare,
    this.onOpenEmergency,
    this.onTriggerSos,
  });

  /// Executes the action based on parsed Gemma intent.
  /// Returns true if an action was taken, false if it was just a chat response.
  bool executeIntent(GemmaResponse response) {
    switch (response.intent) {
      case GemmaIntent.openCompanion:
        if (response.location != null && onOpenCompanionWithLocation != null) {
          onOpenCompanionWithLocation!(response.location!);
        } else if (onOpenCompanion != null) {
          onOpenCompanion!();
        }
        return true;

      case GemmaIntent.openLiveShare:
        onOpenLiveShare?.call();
        return true;

      case GemmaIntent.openEmergency:
        onOpenEmergency?.call();
        return true;

      case GemmaIntent.danger:
        if (response.dangerScore >= 0.75) {
          onTriggerSos?.call();
        } else if (response.dangerScore >= 0.5) {
          onTriggerSos?.call(); // trigger countdown for medium risk too
        }
        return true;

      case GemmaIntent.callEmergency:
        onTriggerSos?.call();
        return true;

      case GemmaIntent.safe:
      case GemmaIntent.chat:
      default:
        return false;
    }
  }

  /// Shows a snackbar notification about what action was taken
  void showActionFeedback(GemmaResponse response) {
    String message;
    Color color;

    switch (response.intent) {
      case GemmaIntent.openCompanion:
        message = '🗺️ Opening Companion Mode${response.location != null ? " → ${response.location}" : ""}';
        color = const Color(0xFF0284C7);
        break;
      case GemmaIntent.openLiveShare:
        message = '📍 Opening Live Location Share';
        color = const Color(0xFF10B981);
        break;
      case GemmaIntent.openEmergency:
        message = '🚨 Opening Nearby Emergency Services';
        color = const Color(0xFF475569);
        break;
      case GemmaIntent.danger:
        message = '⚠️ Danger detected! Triggering SOS...';
        color = const Color(0xFFE8452C);
        break;
      default:
        return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
