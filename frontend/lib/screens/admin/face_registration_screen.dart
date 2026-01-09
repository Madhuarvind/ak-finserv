import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../utils/localizations.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import '../../main.dart'; 
import 'package:google_fonts/google_fonts.dart';

class FaceRegistrationScreen extends StatefulWidget {
  final int userId;
  final String userName;
  final String qrToken;

  const FaceRegistrationScreen({
    super.key, 
    required this.userId, 
    required this.userName,
    required this.qrToken,
  });

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  XFile? _imageFile;
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String? _statusMessage;
  bool _cameraInitialized = false;

  @override
  void initState() {
    super.initState();
    // Camera will be initialized on demand
  }

  void _startCamera() {
    // Use the front camera if available
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
      await _initializeControllerFuture;
      final image = await _controller!.takePicture();
      setState(() {
        _imageFile = image;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _handleRegisterFace() async {
    if (_imageFile == null) {

      return;

    }

    setState(() {
      _isLoading = true;
      _statusMessage = "Processing face...";
    });
    
    try {
      setState(() => _statusMessage = "Processing image...");
      final imageBytes = await _imageFile!.readAsBytes();
      final kb = (imageBytes.lengthInBytes / 1024).toStringAsFixed(1);
      
      final token = await _apiService.getToken();
      
      if (token != null) {
        setState(() => _statusMessage = "Sending to AI ($kb KB)...");
        debugPrint("FACE_DEBUG: Sending $kb KB to registerFace (Admin Screen)");
        
        final result = await _apiService.registerFace(
          widget.userId, 
          imageBytes, 
          'current_device_id', 
          token
        ).timeout(const Duration(seconds: 40));

        final msg = result['msg']?.toString().toLowerCase() ?? '';
        if (result.containsKey('msg') && (msg.contains('success') || msg.contains('registered'))) {
          setState(() => _statusMessage = "Success!");
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.translate('success'))),
          );
          
          await Future.delayed(const Duration(seconds: 1));
          
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context, 
            '/admin/worker_qr', 
            arguments: {
              'user_id': widget.userId, 
              'name': widget.userName,
              'qr_token': widget.qrToken,
            },
          );
        } else {
          final err = result['msg'] ?? result['error'] ?? "failure";
          setState(() => _statusMessage = "Failed: $err");
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.translate(err))),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = "Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Registration Error: ${e.toString()}")),
      );
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              context.translate('face_registration'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.userName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.translate('qr_info'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white38),
                  ),
                  const SizedBox(height: 48),
                  Center(
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primaryColor, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _imageFile != null
                            ? (kIsWeb 
                                ? Image.network(_imageFile!.path, fit: BoxFit.cover)
                                : Image.file(File(_imageFile!.path), fit: BoxFit.cover))
                            : !_cameraInitialized
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.camera_alt_outlined, color: Colors.white24, size: 48),
                                        const SizedBox(height: 12),
                                        ElevatedButton(
                                          onPressed: _startCamera,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primaryColor,
                                            foregroundColor: Colors.black,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  if (_imageFile == null)
                    ElevatedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_rounded),
                      label: Text(context.translate('capture')),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.black,
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _imageFile = null),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(context.translate('retake')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                      ),
                    ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _imageFile == null || _isLoading ? null : _handleRegisterFace,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.black,
                      ),
                      child: _isLoading
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)),
                                const SizedBox(height: 4),
                                Text(_statusMessage ?? "", style: const TextStyle(fontSize: 10, color: Colors.black54)),
                              ],
                            )
                          : Text(
                              context.translate('save_face'), 
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      context.translate('skip'), 
                      style: const TextStyle(color: Colors.white38)
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
