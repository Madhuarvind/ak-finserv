import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../utils/theme.dart';
import '../services/api_service.dart';
import '../utils/localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FaceEnrollmentScreen extends StatefulWidget {
  const FaceEnrollmentScreen({super.key});

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen> {
  CameraController? _controller;
  XFile? _imageFile;
  bool _isProcessing = false;
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  Future<void>? _initializeControllerFuture;
  bool _cameraInitialized = false;
  String? _statusMessage;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Camera will be initialized on demand
  }

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) {
      return;
    }
    
    // Find front camera
    CameraDescription? frontCamera;
    for (var cam in cameras) {
      if (cam.lensDirection == CameraLensDirection.front) {
        frontCamera = cam;
        break;
      }
    }
    
    _controller = CameraController(
      frontCamera ?? cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _cameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  void _startCamera() {
    setState(() {
      _initializeControllerFuture = _initializeCamera();
    });
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) {
      return;
    }

    setState(() => _isProcessing = true);
    
    try {
      final image = await _controller!.takePicture();
      setState(() {
        _imageFile = image;
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Capture Error: $e")));
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _uploadFace() async {
    if (_imageFile == null) {
      return;
    }
    
    setState(() {
      _isProcessing = true;
      _statusMessage = "Starting upload...";
    });
    
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) {
        setState(() => _statusMessage = "Error: Not logged in");
        return;
      }

      setState(() => _statusMessage = "Fetching profile...");
      final profile = await _apiService.getMyProfile(token).timeout(const Duration(seconds: 10));
      
      setState(() => _statusMessage = "Processing image...");
      final imageBytes = await _imageFile!.readAsBytes();
      final kb = (imageBytes.lengthInBytes / 1024).toStringAsFixed(1);
      
      setState(() => _statusMessage = "Sending to AI ($kb KB)...");
      debugPrint("FACE_DEBUG: Sending $kb KB to registerFace");
      
      final result = await _apiService.registerFace(
        profile['id'],
        imageBytes,
        'self_device',
        token,
      ).timeout(const Duration(seconds: 40));

      if (mounted) {
        if (result.containsKey('msg') && result['msg'] == 'face_registered_successfully') {
          setState(() => _statusMessage = "Success!");
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Face registered successfully!")));
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) return;
          Navigator.pop(context, true);
        } else {
          final err = result['msg'] ?? result['error'] ?? "Error registering face";
          setState(() => _statusMessage = "Failed: $err");
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = "Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Error: $e")));
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(context.translate('face_registration'), style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _imageFile != null 
                      ? (kIsWeb 
                          ? Image.network(_imageFile!.path, fit: BoxFit.cover)
                          : Image.file(File(_imageFile!.path), fit: BoxFit.cover))
                      : !_cameraInitialized
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.camera_alt_outlined, color: Colors.white24, size: 64),
                                  const SizedBox(height: 16),
                                  Text("Camera access required", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 16)),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _startCamera,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: const Text("Start Camera"),
                                  ),
                                ],
                              ),
                            )
                          : FutureBuilder<void>(
                              future: _initializeControllerFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.done && 
                                    _controller != null && _controller!.value.isInitialized) {
                                  return CameraPreview(_controller!);
                                } else {
                                  return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                                }
                              },
                            ),
                  // Oval Guide
                  Container(
                    width: 250,
                    height: 350,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(150),
                      border: Border.all(color: Colors.white38, width: 2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _imageFile == null ? context.translate('enrollment_guide') : context.translate('check_photo'),
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 24),
                if (_imageFile == null)
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _takePicture,
                    icon: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.camera_alt_rounded),
                    label: Text(context.translate('capture').toUpperCase()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _imageFile = null;
                                _isProcessing = false;
                                _statusMessage = null;
                                // Reinitialize camera for retake
                                _initializeControllerFuture = _initializeCamera();
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 56),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(context.translate('retake')),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isProcessing ? null : _uploadFace,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 56),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _isProcessing 
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                                      const SizedBox(height: 4),
                                      Text(_statusMessage ?? "", style: const TextStyle(fontSize: 10, color: Colors.white70)),
                                    ],
                                  ) 
                                : Text(context.translate('save')),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
