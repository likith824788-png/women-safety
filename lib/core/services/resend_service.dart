import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ResendService {
  static const String _baseUrl = 'https://api.resend.com';
  static String get _apiKey => dotenv.env['RESEND_API_KEY'] ?? '';
  // Use Resend's test sender for unverified domains
  static const String _fromEmail = 'Aegis Safety <onboarding@resend.dev>';

  static Future<bool> sendSosAlert({
    required List<String> toEmails,
    required String userName,
    required double latitude,
    required double longitude,
    required String triggeredBy,
  }) async {
    if (toEmails.isEmpty) return false;

    final mapsLink = 'https://www.google.com/maps?q=$latitude,$longitude';
    final body = '''
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="font-family: Arial, sans-serif; background: #f7f8fa; padding: 20px;">
  <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.1);">
    <div style="background: #E8452C; padding: 30px; text-align: center;">
      <h1 style="color: white; margin: 0; font-size: 28px;">🚨 EMERGENCY SOS ALERT</h1>
      <p style="color: rgba(255,255,255,0.9); margin: 10px 0 0;">This is an urgent safety alert from Aegis Safety</p>
    </div>
    <div style="padding: 30px;">
      <p style="font-size: 18px; color: #0B1F3A;"><strong>$userName</strong> has triggered an emergency SOS alert.</p>
      <p style="color: #64748B;">Triggered by: <strong>$triggeredBy</strong></p>
      <div style="background: #FDF2F0; border-left: 4px solid #E8452C; padding: 15px; margin: 20px 0; border-radius: 4px;">
        <p style="margin: 0; font-weight: bold; color: #E8452C;">📍 Last Known Location:</p>
        <p style="margin: 5px 0 0; color: #0B1F3A;">Lat: $latitude, Lng: $longitude</p>
      </div>
      <a href="$mapsLink" style="display: block; background: #0B1F3A; color: white; text-align: center; padding: 15px; border-radius: 8px; text-decoration: none; font-size: 16px; font-weight: bold; margin: 20px 0;">
        📍 Open Live Location in Maps
      </a>
      <p style="color: #64748B; font-size: 14px; text-align: center;">Please contact emergency services (911) immediately if you cannot reach them.</p>
    </div>
    <div style="background: #F7F8FA; padding: 15px; text-align: center;">
      <p style="margin: 0; color: #94A3B8; font-size: 12px;">Aegis Safety — Personal Safety App</p>
    </div>
  </div>
</body>
</html>
''';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/emails'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': _fromEmail,
          'to': toEmails,
          'subject': '🚨 EMERGENCY: $userName needs help NOW!',
          'html': body,
        }),
      );

      debugPrint('Resend SOS response: ${response.statusCode} ${response.body}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Resend SOS error: $e');
      return false;
    }
  }

  static Future<bool> sendLiveLocationEmail({
    required List<String> toEmails,
    required String userName,
    required double latitude,
    required double longitude,
    required int durationMinutes,
  }) async {
    if (toEmails.isEmpty) return false;

    final mapsLink = 'https://www.google.com/maps?q=$latitude,$longitude';
    final deepLink = 'https://aegissafety.app/live?uid=user_demo_777&lat=$latitude&lng=$longitude';
    final expiry = durationMinutes == -1 ? 'until stopped manually' : '$durationMinutes minutes';

    final body = '''
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="font-family: Arial, sans-serif; background: #f7f8fa; padding: 20px;">
  <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.1);">
    <div style="background: #0B1F3A; padding: 30px; text-align: center;">
      <h1 style="color: white; margin: 0; font-size: 24px;">📍 Live Location Shared</h1>
      <p style="color: rgba(255,255,255,0.8); margin: 10px 0 0;">$userName is sharing their live location with you</p>
    </div>
    <div style="padding: 30px;">
      <p style="font-size: 16px; color: #0B1F3A;"><strong>$userName</strong> has started sharing their live location with you for <strong>$expiry</strong>.</p>
      <div style="background: #EDF1F7; border-radius: 8px; padding: 15px; margin: 20px 0;">
        <p style="margin: 0; color: #64748B; font-size: 14px;">Current Location:</p>
        <p style="margin: 5px 0 0; font-weight: bold; color: #0B1F3A;">Lat: $latitude, Lng: $longitude</p>
      </div>
      <a href="$deepLink" style="display: block; background: #10B981; color: white; text-align: center; padding: 15px; border-radius: 8px; text-decoration: none; font-size: 16px; font-weight: bold; margin: 20px 0;">
        🛡️ Open in Aegis Safety App
      </a>
      <a href="$mapsLink" style="display: block; background: #0B1F3A; color: white; text-align: center; padding: 12px; border-radius: 8px; text-decoration: none; font-size: 14px; font-weight: bold;">
        📍 View in Google Maps
      </a>
    </div>
    <div style="background: #F7F8FA; padding: 15px; text-align: center;">
      <p style="margin: 0; color: #94A3B8; font-size: 12px;">Aegis Safety — Personal Safety App</p>
    </div>
  </div>
</body>
</html>
''';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/emails'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': _fromEmail,
          'to': toEmails,
          'subject': '📍 $userName is sharing their live location with you',
          'html': body,
        }),
      );

      debugPrint('Resend Location response: ${response.statusCode} ${response.body}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Resend Location error: $e');
      return false;
    }
  }

  /// Sends a route deviation alert email to trusted contacts.
  static Future<bool> sendDeviationAlert({
    required List<String> toEmails,
    required String userName,
    required String destination,
    required double latitude,
    required double longitude,
    required double deviationMeters,
  }) async {
    if (toEmails.isEmpty) return false;
    final mapsLink = 'https://www.google.com/maps?q=$latitude,$longitude';
    final body = '''<!DOCTYPE html>
<html><head><meta charset="UTF-8"></head>
<body style="font-family: Arial, sans-serif; background: #f7f8fa; padding: 20px;">
  <div style="max-width:600px;margin:0 auto;background:white;border-radius:12px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.1);">
    <div style="background:#F59E0B;padding:28px;text-align:center;">
      <h1 style="color:white;margin:0;font-size:26px;">⚠️ ROUTE DEVIATION ALERT</h1>
      <p style="color:rgba(255,255,255,0.9);margin:10px 0 0;">Suspicious activity detected</p>
    </div>
    <div style="padding:28px;">
      <p style="font-size:17px;color:#0B1F3A;"><strong>$userName</strong> has deviated from their planned route.</p>
      <p style="color:#64748B;">Destination: <strong>$destination</strong></p>
      <div style="background:#FEF3C7;border-left:4px solid #F59E0B;padding:15px;margin:20px 0;border-radius:4px;">
        <p style="margin:0;font-weight:bold;color:#B45309;">📍 Current Location (off-route):</p>
        <p style="margin:5px 0 0;color:#0B1F3A;">Lat: $latitude, Lng: $longitude</p>
        <p style="margin:5px 0 0;color:#B45309;">Deviation: ~${deviationMeters.round()}m from planned route</p>
      </div>
      <a href="$mapsLink" style="display:block;background:#F59E0B;color:white;text-align:center;padding:15px;border-radius:8px;text-decoration:none;font-size:16px;font-weight:bold;margin:20px 0;">
        📍 View Current Location in Maps
      </a>
      <p style="color:#64748B;font-size:14px;">Please check in with $userName immediately. If they don't respond, contact emergency services.</p>
    </div>
    <div style="background:#F7F8FA;padding:15px;text-align:center;">
      <p style="margin:0;color:#94A3B8;font-size:12px;">Aegis Safety — Personal Safety App</p>
    </div>
  </div>
</body></html>''';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/emails'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': _fromEmail,
          'to': toEmails,
          'subject': '⚠️ ALERT: $userName has gone off-route!',
          'html': body,
        }),
      );
      debugPrint('Deviation alert response: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Deviation alert error: $e');
      return false;
    }
  }

  /// Sends an escalation alert (30-min off-route) to nearby services & contacts.
  static Future<bool> sendEscalationAlert({
    required List<String> toEmails,
    required String userName,
    required String destination,
    required double latitude,
    required double longitude,
    required int minutesDeviated,
  }) async {
    if (toEmails.isEmpty) return false;
    final mapsLink = 'https://www.google.com/maps?q=$latitude,$longitude';
    final body = '''<!DOCTYPE html>
<html><head><meta charset="UTF-8"></head>
<body style="font-family: Arial, sans-serif; background: #f7f8fa; padding: 20px;">
  <div style="max-width:600px;margin:0 auto;background:white;border-radius:12px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.1);">
    <div style="background:#E8452C;padding:28px;text-align:center;">
      <h1 style="color:white;margin:0;font-size:26px;">🚨 ESCALATION: OFF-ROUTE $minutesDeviated MINUTES</h1>
      <p style="color:rgba(255,255,255,0.9);margin:10px 0 0;">Emergency escalation — notify nearby services</p>
    </div>
    <div style="padding:28px;">
      <p style="font-size:17px;color:#0B1F3A;"><strong>$userName</strong> has been off their planned route for <strong>$minutesDeviated minutes</strong> with no return.</p>
      <p style="color:#64748B;">Planned destination: <strong>$destination</strong></p>
      <div style="background:#FDF2F0;border-left:4px solid #E8452C;padding:15px;margin:20px 0;border-radius:4px;">
        <p style="margin:0;font-weight:bold;color:#E8452C;">📍 Last Known Location:</p>
        <p style="margin:5px 0 0;color:#0B1F3A;">Lat: $latitude, Lng: $longitude</p>
      </div>
      <a href="$mapsLink" style="display:block;background:#E8452C;color:white;text-align:center;padding:15px;border-radius:8px;text-decoration:none;font-size:16px;font-weight:bold;margin:20px 0;">
        🚨 View Location — Contact Emergency Services
      </a>
      <p style="color:#E8452C;font-weight:bold;font-size:15px;">Please call emergency services (112/911) immediately and share this location.</p>
    </div>
    <div style="background:#F7F8FA;padding:15px;text-align:center;">
      <p style="margin:0;color:#94A3B8;font-size:12px;">Aegis Safety — Personal Safety App</p>
    </div>
  </div>
</body></html>''';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/emails'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': _fromEmail,
          'to': toEmails,
          'subject': '🚨 EMERGENCY: $userName off-route for ${minutesDeviated}min — Contact services!',
          'html': body,
        }),
      );
      debugPrint('Escalation alert response: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Escalation alert error: $e');
      return false;
    }
  }
}
