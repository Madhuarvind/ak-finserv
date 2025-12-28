import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class ApiService {
  // Replace with your machine's IP (e.g., 192.168.1.5) if testing on a physical device
  static const String _serverAddress = '192.168.43.113'; 

  static String get baseUrl {
    if (kIsWeb) {
      // Use 127.0.0.1 explicitly if host is localhost to avoid "Failed to fetch"
      final host = Uri.base.host;
      final serverHost = (host == 'localhost' || host == '127.0.0.1') ? '127.0.0.1' : host;
      return 'http://$serverHost:5000/api/auth';
    }
    // Mobile/Desktop path
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:5000/api/auth';
      }
    } catch (e) {}
    return 'http://$_serverAddress:5000/api/auth';
  }
  final _storage = const FlutterSecureStorage();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<String?> _getDeviceId() async {
    if (kIsWeb) return 'web_device';
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor;
      }
    } catch (e) {
      return 'unknown_device';
    }
    return 'desktop_device';
  }

  Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: 'jwt_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  Future<void> saveUserData(String name, String role) async {
    await _storage.write(key: 'user_name', value: name);
    await _storage.write(key: 'user_role', value: role);
  }

  Future<String?> getUserName() async {
    return await _storage.read(key: 'user_name');
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: 'refresh_token');
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<void> clearAuth() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'user_name');
    await _storage.delete(key: 'user_role');
  }

  // Silent Login / Refresh Logic
  Future<bool> ensureAuthenticated() async {
    final token = await getToken();
    if (token == null) return false;
    
    // Check if token is expired (simulated here, but real app would check JWT payload)
    // For now, we attempt to refresh if any error occurs in other calls
    return true;
  }

  Future<Map<String, dynamic>> sendOtp(String mobileNumber) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mobile_number': mobileNumber}),
      ).timeout(const Duration(seconds: 10));
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      return jsonDecode(response.body);
    } catch (e) {
      print('API Error: $e');
      return {'msg': 'Error: $e'}; 
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String mobileNumber, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mobile_number': mobileNumber, 'otp': otp}),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      print('API Error: $e');
      return {'msg': 'connection_failed', 'details': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setPin(String name, String pin) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/set-pin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'pin': pin}),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      print('API Error: $e');
      return {'msg': 'connection_failed', 'details': e.toString()};
    }
  }

  Future<Map<String, dynamic>> loginPin(String name, String pin) async {
    final deviceId = await _getDeviceId();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login-pin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name, 
          'pin': pin,
          'device_id': deviceId
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('API Error: $e');
      return {'msg': 'connection_failed', 'details': e.toString()};
    }
  }

  Future<Map<String, dynamic>> registerWorker(
    String name, 
    String mobile, 
    String pin, 
    String token, {
    String? area,
    String? address,
    String? idProof,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register-worker'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'mobile_number': mobile, 
          'pin': pin,
          'area': area,
          'address': address,
          'id_proof': idProof,
        }),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      print('API Error: $e');
      return {'msg': 'connection_failed', 'details': e.toString()};
    }
  }

  Future<Map<String, dynamic>> registerFace(int userId, List<double> embedding, String? deviceId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register-face'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'user_id': userId,
          'embedding': embedding,
          'device_id': deviceId
        }),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      print('API Error: $e');
      return {'msg': 'connection_failed', 'details': e.toString()};
    }
  }

  Future<Map<String, dynamic>> resetDevice(int userId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reset-device'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'user_id': userId}),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      print('API Error: $e');
      return {'msg': 'connection_failed', 'details': e.toString()};
    }
  }

  Future<dynamic> getUsers(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('API Error: $e');
      return {'msg': 'connection_failed'}; 
    }
  }

  Future<Map<String, dynamic>> adminLogin(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username, 
          'password': password
        }),
      );
      print('AdminLogin Response: ${response.statusCode}');
      return jsonDecode(response.body);
    } catch (e) {
      print('API Error: $e');
      return {'msg': 'connection_failed'}; 
    }
  }

  Future<Map<String, dynamic>> adminVerify(String mobileNumber, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin-verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mobile_number': mobileNumber, 'otp': otp}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('API Error: $e');
      return {'msg': 'connection_failed'}; 
    }
  }

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/refresh-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $refreshToken',
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('API Error: $e');
      return {'msg': 'connection_failed'}; 
    }
  }

  Future<Map<String, dynamic>> verifyFaceLogin(
    String name, 
    List<double> embedding
  ) async {
    final deviceId = await _getDeviceId();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-face-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'embedding': embedding,
          'device_id': deviceId
        }),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      print('API Error: $e');
      return {'msg': 'connection_failed', 'details': e.toString()};
    }
  }

  Future<List<dynamic>> getAuditLogs(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/audit-logs'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('Audit Logs API Error: $e');
      return [];
    }
  }
}
