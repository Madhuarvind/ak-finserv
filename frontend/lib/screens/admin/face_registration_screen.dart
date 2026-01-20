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
  Uint8List? _webImageBytes;

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
      final imageBytes = (kIsWeb && _webImageBytes != null) 
          ? _webImageBytes! 
          : await _imageFile!.readAsBytes();
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
        SnackBar(
          content: Text("Critical Registration Error: ${e.toString()}"),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(label: "DISMISS", onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar()),
        ),
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
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: Text(
              context.translate('face_registration'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
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
              padding: const EdgeInsets.fromLTRB(32, 100, 32, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.userName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
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
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primaryColor, width: 2),
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
                            ? (kIsWeb && _webImageBytes != null
                                ? Image.memory(_webImageBytes!, fit: BoxFit.cover)
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
                      label: Text(context.translate('capture'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _imageFile = null),
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                      label: Text(context.translate('retake'), style: GoogleFonts.outfit(color: Colors.white70)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _imageFile == null || _isLoading ? null : _handleRegisterFace,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        backgroundColor: _imageFile == null ? Colors.grey.withValues(alpha: 0.2) : Colors.white,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.grey.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)),
                                const SizedBox(width: 12),
                                Text(_statusMessage ?? "", style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54)),
                              ],
                            )
                          : Text(
                              context.translate('save_face'), 
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      context.translate('skip'), 
                      style: GoogleFonts.outfit(color: Colors.white38)
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
