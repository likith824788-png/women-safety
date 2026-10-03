import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class TwilioService {
  static String get _accountSid => dotenv.env['TWILIO_ACCOUNT_SID'] ?? '';
  static String get _authToken => dotenv.env['TWILIO_AUTH_TOKEN'] ?? '';

  /// Default emergency phone numbers provided by user
  static const List<String> defaultEmergencyNumbers = [
    '9100771523',
    '9025174327',
    '6382104870',
    '7569228039',
  ];

  /// Sends an emergency SMS via Twilio API, with SMS url_launcher fallback for client devices
  static Future<bool> sendSosSms({
    required List<String> phoneNumbers,
    required String userName,
    required double latitude,
    required double longitude,
    required String triggeredBy,
  }) async {
    final targets = phoneNumbers.isEmpty ? defaultEmergencyNumbers : phoneNumbers;
    final message =
        '🚨 EMERGENCY SOS ALERT!\n$userName needs help NOW!\nTriggered by: $triggeredBy\nLocation: https://maps.google.com/?q=$latitude,$longitude';

    bool successAny = false;

    for (var phone in targets) {
      final formattedPhone = phone.startsWith('+') ? phone : '+91$phone';
      try {
        final url = Uri.parse(
            'https://api.twilio.com/2010-04-01/Accounts/$_accountSid/Messages.json');
        final authHeader =
            'Basic ${base64Encode(utf8.encode('$_accountSid:$_authToken'))}';

        final response = await http.post(
          url,
          headers: {
            'Authorization': authHeader,
            'Content-Type': 'application/x-www-form-request-body; charset=utf-8',
          },
          body: {
            'To': formattedPhone,
            'From': '+18005550199', // Default Twilio sender
            'Body': message,
          },
        );

        debugPrint('Twilio response ($formattedPhone): ${response.statusCode}');
        if (response.statusCode == 200 || response.statusCode == 201) {
          successAny = true;
        }
      } catch (e) {
        debugPrint('Twilio SMS API error: $e');
      }

      // Fallback: Open SMS app on mobile if API call fails
      try {
        final smsUri = Uri.parse('sms:$formattedPhone?body=${Uri.encodeComponent(message)}');
        if (await canLaunchUrl(smsUri)) {
          await launchUrl(smsUri);
          successAny = true;
        }
      } catch (e) {
        debugPrint('SMS launcher error: $e');
      }
    }

    return successAny;
  }
}
