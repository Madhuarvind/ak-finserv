import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class ApiService {
  // Your PC's IP address
  static const String _localIp = '172.1.25.67'; 
  
  // Using Local IP for Release testing so you can use the APK on your phone via WiFi
  static const String _productionUrl = 'https://vasool-drive-backend.onrender.com/api/auth'; 

  static String get baseUrl {
    if (kReleaseMode) {
      // In release mode (APK), use the production URL
      // If you are just testing the APK locally, you can change this to use _localIp
      return _productionUrl; 
    }
    
    if (kIsWeb || Platform.isWindows) {
      return 'http://localhost:5000/api/auth';
    }
    
    if (Platform.isAndroid) {
      // 10.0.2.2 is the special IP for Android Emulator to access host localhost
      // If running on physical device, we need the LAN IP
      return 'http://$_localIp:5000/api/auth';
    }
    
    return 'http://$_localIp:5000/api/auth';
  }

  String get _apiBase => baseUrl.replaceFirst('/auth', '');
  final _storage = FlutterSecureStorage();



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

  Future<String?> getUserRole() async {
    return await _storage.read(key: 'user_role');
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
    if (token == null) {

      return false;

    }
    
    // Check if token is expired (simulated here, but real app would check JWT payload)
    // For now, we attempt to refresh if any error occurs in other calls
    return true;
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
      debugPrint('API Error: $e');
      return {'msg': 'connection_failed', 'details': e.toString()};
    }
  }

  Future<Map<String, dynamic>> loginPin(String name, String pin, {String? deviceId}) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/auth/login-pin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'pin': pin,
          if (deviceId != null) 'device_id': deviceId
        }),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Error: $e');
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
    String? role,
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
          'role': role ?? 'field_agent',
        }),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Error: $e');
      return {'msg': 'connection_failed', 'details': e.toString()};
    }
  }

  Future<Map<String, dynamic>> registerFace(int userId, dynamic imageBytes, String? deviceId, String token) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_apiBase/auth/register-face'));
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['user_id'] = userId.toString();
      if (deviceId != null) request.fields['device_id'] = deviceId;
      
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'face.jpg',
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint("API_DEBUG: registerFace connection error: $e");
      return {'msg': 'connection_failed', 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> verifyFaceLogin(String name, dynamic imageBytes, String? deviceId) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_apiBase/auth/verify-face-login'));
      request.fields['name'] = name;
      if (deviceId != null) request.fields['device_id'] = deviceId;
      
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'verify.jpg',
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('verifyFaceLogin Error: $e');
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
      debugPrint('API Error: $e');
      return {'msg': 'connection_failed', 'details': e.toString()};
    }
  }

  Future<List<dynamic>> getUsers(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      debugPrint('API Error: $e');
      return []; 
    }
  }

  Future<Map<String, dynamic>> getUserDetail(int userId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Error: $e');
      return {'msg': 'connection_failed'};
    }
  }

  Future<Map<String, dynamic>> updateUser(int userId, Map<String, dynamic> data, String token) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Error: $e');
      return {'msg': 'connection_failed'};
    }
  }

  Future<Map<String, dynamic>> patchUserStatus(int userId, Map<String, dynamic> statusData, String token) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/users/$userId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(statusData),
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Error: $e');
      return {'msg': 'connection_failed'};
    }
  }

  Future<Map<String, dynamic>> clearBiometrics(int userId, String token) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/users/$userId/biometrics'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Error: $e');
      return {'msg': 'connection_failed'};
    }
  }

  Future<Map<String, dynamic>> resetUserPin(int userId, String newPin, String token) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/users/$userId/reset-pin'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'new_pin': newPin}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Error: $e');
      return {'msg': 'connection_failed'};
    }
  }

  Future<Map<String, dynamic>> deleteUser(int userId, String token) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Error: $e');
      return {'msg': 'connection_failed'};
    }
  }

  Future<Map<String, dynamic>> getUserBiometrics(int userId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/biometrics-info'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Error: $e');
      return {'msg': 'connection_failed', 'has_biometric': false};
    }
  }

  Future<Map<String, dynamic>> getUserLoginStats(int userId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/login-stats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Error: $e');
      return {'msg': 'connection_failed', 'total_logins': 0, 'failed_logins': 0};
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
      debugPrint('AdminLogin Response: ${response.statusCode}');
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Error: $e');
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
      debugPrint('API Error: $e');
      return {'msg': 'connection_failed'}; 
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
      debugPrint('Audit Logs API Error: $e');
      return [];
    }
  }

  Future<List<dynamic>> getLoans({String? status, required String token}) async {
    try {
      final url = status != null 
          ? '$_apiBase/loan/all?status=$status' 
          : '$_apiBase/loan/all';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }



  Future<Map<String, dynamic>> forecloseLoan(int loanId, double amount, String reason, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/loan/$loanId/foreclose'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'settlement_amount': amount,
          'reason': reason
        }),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed: $e'};
    }
  }

  Future<Map<String, dynamic>> getMyProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/my-profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  Future<List<dynamic>> getMyTeam(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/my-team'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }



  // Collection & Customer Management
  Future<List<dynamic>> getCustomers(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/customer/list'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('customers')) {
          return decoded['customers'] as List<dynamic>;
        }
        return (decoded is List) ? decoded : [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createCustomer(Map<String, dynamic> data, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/customer/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  Future<List<dynamic>> getCustomerLoans(int customerId, String token) async {
    final url = '$_apiBase/collection/loans/$customerId';
    try {
      debugPrint('GET $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 10));
      debugPrint('Response ${response.statusCode}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      debugPrint('GetCustomerLoans error at $url: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> submitCollection({
    required int loanId,
    required double amount,
    required String paymentMode,
    int? lineId,
    double? latitude,
    double? longitude,
    required String token,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/collection/submit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'loan_id': loanId,
          'amount': amount,
          'payment_mode': paymentMode,
          'line_id': lineId,
          'latitude': latitude,
          'longitude': longitude,
        }),
      ).timeout(const Duration(seconds: 10));
      debugPrint('SubmitCollection Response: ${response.statusCode}');
      debugPrint('SubmitCollection Body: ${response.body}');
      if (response.statusCode != 200 && response.statusCode != 201) {
        return {'msg': 'Server Error: ${response.statusCode}', 'body': response.body};
      }
      final decoded = jsonDecode(response.body);
      return decoded;
    } catch (e) {
      debugPrint('SubmitCollection Error: $e');
      return {'msg': 'connection_failed: $e'};
    }
  }

  Future<Map<String, dynamic>> updateCollectionStatus(int collectionId, String status, String token) async {
    try {
      final response = await http.patch(
        Uri.parse('$_apiBase/collection/$collectionId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': status}),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  // QR Code Lookup
  Future<Map<String, dynamic>> getCustomerByQr(String qrCode) async {
    final token = await _storage.read(key: 'jwt_token');
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/customer/qr/${Uri.encodeComponent(qrCode)}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'msg': 'not_found'};
      }
    } catch (e) {
      return {'msg': 'connection_error'};
    }
  }

  Future<Map<String, dynamic>> getAgentStats(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/collection/stats/agent'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body) ?? {'msg': 'empty_response'};
      }
      return {'msg': 'server_error', 'code': response.statusCode};
    } catch (e) {
      debugPrint('getAgentStats Error: $e');
      return {'msg': 'connection_failed'};
    }
  }

  Future<List<dynamic>> getPendingCollections(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/collection/pending-collections'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body) ?? [];
      }
      return [];
    } catch (e) {
      debugPrint('getPendingCollections Error: $e');
      return [];
    }
  }

  Future<List<dynamic>> getCollectionHistory(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/collection/history'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body) ?? [];
      }
      return [];
    } catch (e) {
      debugPrint('getCollectionHistory Error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getFinancialStats(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/collection/stats/financials'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  Future<Map<String, dynamic>> getKPIStats(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/reports/stats/kpi'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  Future<Map<String, dynamic>> getDailyReport(String token, {String? startDate, String? endDate}) async {
    try {
      String query = '';
      if (startDate != null) query += '?start_date=$startDate';
      if (endDate != null) query += '${query.isEmpty ? '?' : '&'}end_date=$endDate';
      
      final response = await http.get(
        Uri.parse('$_apiBase/reports/daily$query'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  Future<Map<String, dynamic>> getAutoAccountingData() async {
    try {
      // NOTE: We recently disabled @jwt_required on this endpoint for easier n8n/widget integration
      final response = await http.get(
        Uri.parse('$_apiBase/reports/auto-accounting'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'msg': 'error', 'status': response.statusCode};
    } catch (e) {
      return {'msg': 'connection_failed', 'details': e.toString()};
    }
  }

  Future<List<dynamic>> getOutstandingReport(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/reports/outstanding'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getOverdueReport(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/reports/risk/overdue'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getAgentPerformanceList(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/reports/performance'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getPerformanceStats(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stats/performance'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  // Line Management
  Future<Map<String, dynamic>> createLine(Map<String, dynamic> data, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/line/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }


  Future<List<dynamic>> getDailyReportsArchive(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/reports/daily-archive'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Uint8List?> getDailyReportPDF(int reportId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/reports/daily/pdf/$reportId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      debugPrint('getDailyReportPDF error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> updateLine(int lineId, Map<String, dynamic> data, String token) async {
    try {
      final response = await http.patch(
        Uri.parse('$_apiBase/line/$lineId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed: $e'};
    }
  }

  Future<List<dynamic>> getAllLines(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/line/all'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // System Settings
  Future<Map<String, dynamic>> getSystemSettings(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/settings/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, dynamic>> updateSystemSettings(Map<String, dynamic> data, String token) async {
    try {
      final response = await http.put(
        Uri.parse('$_apiBase/settings/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  // Document Management
  Future<Map<String, dynamic>> uploadLoanDocument(int loanId, String filePath, String docType, String token) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_apiBase/document/loan/$loanId/upload'));
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['doc_type'] = docType;
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      
      var response = await request.send().timeout(const Duration(seconds: 30));
      var responseBody = await response.stream.bytesToString();
      return jsonDecode(responseBody);
    } catch (e) {
      return {'msg': 'upload_failed', 'error': e.toString()};
    }
  }

  Future<List<dynamic>> getLoanDocuments(int loanId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/document/loan/$loanId/documents'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return [];
    }
  }


  // AI Analytics
  Future<Map<String, dynamic>> getRiskScore(int customerId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/analytics/risk-score/$customerId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'analysis_failed', 'risk_score': 0, 'risk_level': 'N/A'};
    }
  }

  Future<Map<String, dynamic>> getRiskDashboard(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/analytics/risk-dashboard'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {};
    }
  }

  Future<List<dynamic>> getWorkerPerformanceAnalytics(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/analytics/worker-performance'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getCustomerBehaviorAnalytics(int customerId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/analytics/customer-behavior/$customerId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      return {'segment': 'ERROR', 'reliability_score': 0};
    }
  }

  Future<Map<String, dynamic>> getDashboardAIInsights(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/analytics/dashboard-ai-insights'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      return {'ai_summaries': ['AI analysis unavailable at this moment.']};
    }
  }

  Future<List<dynamic>> getWorkTargets(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/reports/work-targets'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      debugPrint('getWorkTargets Error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getSecurityFlags(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/security/role-abuse-detection'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'flags': []};
    }
  }

  Future<Map<String, dynamic>> getTamperDetection(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/security/tamper-detection'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'alerts': []};
    }
  }

  Future<List<dynamic>> getDeviceMonitoring(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/security/device-health'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return jsonDecode(response.body);
    } catch (e) {
      return [];
    }
  }

  String getAuditExportUrl() {
    return '$_apiBase/security/audit-export';
  }

  Future<Map<String, dynamic>> getPenaltySummary(int loanId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/document/loan/$loanId/penalty-summary'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }


  Future<Map<String, dynamic>> assignLineAgent(int lineId, int agentId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/line/$lineId/assign-agent'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'agent_id': agentId}),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  Future<Map<String, dynamic>> toggleLineLock(int lineId, String token) async {
    try {
      final response = await http.patch(
        Uri.parse('$_apiBase/line/$lineId/lock'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  Future<List<dynamic>> getLineCustomers(int lineId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/line/$lineId/customers'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> addCustomerToLine(int lineId, int customerId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/line/$lineId/add-customer'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'customer_id': customerId}),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  Future<Map<String, dynamic>> reorderLineCustomers(int lineId, List<int> order, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/line/$lineId/reorder'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'order': order}),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }
  Future<Map<String, dynamic>> removeCustomerFromLine(int lineId, int customerId, String token) async {
    try {
      final response = await http.delete(
        Uri.parse('$_apiBase/line/$lineId/customer/$customerId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  // --- Settlement ---
  Future<List<dynamic>> getDailySettlements(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/settlement/today'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> verifySettlement(Map<String, dynamic> data, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/settlement/verify'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  Future<List<dynamic>> getSettlementHistory(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/settlement/history'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      debugPrint('getSettlementHistory Error: $e');
      return [];
    }
  }

  Future<List<dynamic>> getRawTableData(String tableName, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/admin/raw-table/$tableName'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      debugPrint('getRawTableData Error: $e');
      return [];
    }
  }

  // --- Customer Sync ---
  Future<Map<String, dynamic>?> syncCustomers(List<Map<String, dynamic>> customers, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/customer/sync'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'customers': customers}),
      ).timeout(const Duration(seconds: 30));

      debugPrint('Sync Response: ${response.statusCode}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Sync error: $e');
      return null;
    }
  }
  // --- Customer Management (Admin/Online) ---
  Future<Map<String, dynamic>> getAllCustomers({int page = 1, String search = '', String token = ''}) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/customer/list?page=$page&search=$search'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'customers': [], 'total': 0};
    } catch (e) {
      debugPrint('GetAllCustomers error: $e');
      return {'customers': [], 'total': 0};
    }
  }

  Future<Map<String, dynamic>?> getCustomerDetail(int id, String token) async {
    final url = '$_apiBase/customer/$id';
    try {
      debugPrint('GET $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('Response ${response.statusCode}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      debugPrint('Error status code: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      debugPrint('GetCustomerDetail error at $url: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> createCustomerOnline(Map<String, dynamic> customerData, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/customer/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(customerData),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Create customer online error: $e');
      return {'msg': 'connection_failed'};
    }
  }

  Future<Map<String, dynamic>> updateCustomer(int id, Map<String, dynamic> data, String token) async {
    try {
      final response = await http.put(
        Uri.parse('$_apiBase/customer/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  // --- Loan Management ---
  Future<Map<String, dynamic>> createLoan(Map<String, dynamic> data, String token) async {
    final url = '$_apiBase/loan/create';
    try {
      debugPrint('POST $url');
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('Response ${response.statusCode}: ${response.body}');
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('CreateLoan Error at $url: $e');
      return {'msg': 'connection_failed', 'details': e.toString()};
    }
  }

  Future<Map<String, dynamic>> approveLoan(int id, Map<String, dynamic> data, String token) async {
    try {
      final response = await http.patch(
        Uri.parse('$_apiBase/loan/$id/approve'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  Future<Map<String, dynamic>> activateLoan(int id, String token) async {
    try {
      final response = await http.patch(
        Uri.parse('$_apiBase/loan/$id/activate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  Future<Map<String, dynamic>> getLoanDetails(int id, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/loan/$id'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  // Phase 3A: Production Customer Management
  Future<Map<String, dynamic>> updateCustomerStatus(int id, String status, String token) async {
    try {
      final response = await http.put(
        Uri.parse('$_apiBase/customer/$id/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': status}),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  Future<Map<String, dynamic>> toggleCustomerLock(int id, bool lock, String token) async {
    try {
      final endpoint = lock ? 'lock' : 'unlock';
      final response = await http.post(
        Uri.parse('$_apiBase/customer/$id/$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  Future<Map<String, dynamic>> checkDuplicateCustomer(String name, String mobile, String area, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/customer/check-duplicate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'mobile_number': mobile,
          'area': area,
        }),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'duplicates_found': false, 'count': 0, 'duplicates': []};
    }
  }
  Future<List<dynamic>> optimizeRoute(int lineId, double lat, double lng, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/line/$lineId/optimize'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'latitude': lat,
          'longitude': lng,
        }),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      debugPrint('optimizeRoute Error: $e');
      return [];
    }
  }

  Future<List<dynamic>> getDueTomorrowReminders(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/reports/reminders/due-tomorrow'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      debugPrint('getDueTomorrowReminders Error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> sendBulkReminders(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/reports/reminders/send-all'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  Future<Map<String, dynamic>> askAiAnalyst(String query, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/admin/ai-analyst'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'query': query}),
      ).timeout(const Duration(seconds: 20));
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'text': 'I encountered a connection error. Please check your internet.',
        'type': 'error'
      };
    }
  }

  Future<Map<String, dynamic>> getAIInsights(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/reports/dashboard-insights'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      debugPrint('getAIInsights Error: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getDailyOpsSummary(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/reports/daily-ops-summary'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      debugPrint('getDailyOpsSummary Error: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> bulkReassignAgent(int fromId, int toId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/line/bulk-reassign'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'from_agent_id': fromId,
          'to_agent_id': toId,
        }),
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  // Digital Passbook
  Future<Map<String, dynamic>> getPassbookShareToken(int customerId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/customer/$customerId/share-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  Future<Map<String, dynamic>> getPublicPassbook(String pbToken) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/customer/public/passbook/$pbToken'),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  Future<Map<String, dynamic>> getLineSummaryReport(int lineId, String period, String? date, String token) async {
    try {
      String query = '?period=$period';
      if (date != null) query += '&date=$date';
      
      final response = await http.get(
        Uri.parse('$_apiBase/reports/line/$lineId$query'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'msg': 'server_error', 'code': response.statusCode};
    } catch (e) {
      debugPrint('getLineSummaryReport Error: $e');
      return {'msg': 'connection_failed'};
    }
  }

  // --- Resource Optimization ---
  Future<Map<String, dynamic>> autoAssignWorkers(String token, {String? area, int? maxPerWorker, bool dryRun = false}) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/ops/auto-assign-workers'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'area': area,
          'max_per_worker': maxPerWorker,
          'dry_run': dryRun
        }),
      ).timeout(const Duration(seconds: 30));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  Future<Map<String, dynamic>> getBudgetSuggestion(String token, {double fund = 1000000}) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/ops/budget-suggestion?fund=$fund'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  // --- Worker Tracking & Status ---
  Future<Map<String, dynamic>> updateWorkerTracking({
    required String token,
    double? latitude,
    double? longitude,
    String? dutyStatus,
    String? activity,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/worker/update-tracking'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'duty_status': dutyStatus,
          'activity': activity,
        }),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }

  Future<List<dynamic>> getFieldAgentsLocation(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/worker/field-map'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      debugPrint('getFieldAgentsLocation Error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> selfEnrollBiometric(String token, List<dynamic> embedding, String? deviceId) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/worker/self-enroll-biometric'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'embedding': embedding,
          'device_id': deviceId,
        }),
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      return {'msg': 'connection_failed'};
    }
  }
}
