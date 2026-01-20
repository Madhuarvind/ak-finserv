import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../main.dart'; 
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/theme.dart';

class FaceEnrollmentScreen extends StatefulWidget {
  const FaceEnrollmentScreen({super.key});

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  XFile? _imageFile;
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;
  bool _cameraInitialized = false;
  Uint8List? _webImageBytes;

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  void _startCamera() {
    if (cameras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No cameras found")));
      return;
    }

    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    setState(() {
      _initializeControllerFuture = _controller!.initialize().then((_) {
        if (mounted) {
          setState(() => _cameraInitialized = true);
        }
      });
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      if (_controller == null || !_controller!.value.isInitialized) {
        throw "Camera not ready";
      }
      final image = await _controller!.takePicture();
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        if (mounted) {
          setState(() {
            _imageFile = image;
            _webImageBytes = bytes;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _imageFile = image;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _handleEnrollFace() async {
    if (_imageFile == null) return;

    setState(() => _isLoading = true);
    
    try {
      final imageBytes = (kIsWeb && _webImageBytes != null) 
          ? _webImageBytes! 
          : await _imageFile!.readAsBytes();
          
      final token = await _storage.read(key: 'jwt_token');
      
      if (token != null) {
        final result = await _apiService.registerFace(
          0,
          imageBytes, 
          'local_device', 
          token
        ).timeout(const Duration(seconds: 40));

        final msg = result['msg']?.toString().toLowerCase() ?? '';
        if (msg.contains('success') || msg.contains('registered')) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Biometric enrolled successfully!")));
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) return;
          Navigator.pop(context, true);
        } else {
          final err = result['msg'] ?? result['error'] ?? "failure";
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Enrollment Error: $err")));
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Critical Error: $e"),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(label: "DISMISS", onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar()),
        )
      );
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Text("Enroll Biometrics", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SingleChildScrollView(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("Facial Recognition", textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text("Position your face in the circle to enroll.", textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.white54)),
                  const SizedBox(height: 40),
                  Center(
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primaryColor, width: 4),
                        boxShadow: [
                          BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 40)
                        ],
                      ),
                      child: ClipOval(
                        child: _imageFile != null
                            ? (kIsWeb && _webImageBytes != null
                                ? Image.memory(_webImageBytes!, fit: BoxFit.cover)
                                : Image.file(File(_imageFile!.path), fit: BoxFit.cover))
                            : FutureBuilder<void>(
                                future: _initializeControllerFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.done && _cameraInitialized) {
                                    return CameraPreview(_controller!);
                                  } else if (snapshot.hasError) {
                                    return const Center(child: Text("Camera Error", style: TextStyle(color: Colors.red)));
                                  } else {
                                    return const Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircularProgressIndicator(color: AppTheme.primaryColor),
                                          SizedBox(height: 10),
                                          Text("Starting Camera...", style: TextStyle(color: Colors.white54, fontSize: 12)),
                                        ],
                                      ),
                                    );
                                  }
                                },
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (_imageFile == null)
                    ElevatedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: Text("CAPTURE PHOTO", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    )
                  else
                    Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _handleEnrollFace,
                          icon: const Icon(Icons.check_circle_rounded),
                          label: Text(_isLoading ? "ENROLLING..." : "CONFIRM ENROLLMENT", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => setState(() => _imageFile = null), 
                          child: Text("RETAKE PHOTO", style: GoogleFonts.outfit(color: Colors.white70, fontWeight: FontWeight.bold))
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
