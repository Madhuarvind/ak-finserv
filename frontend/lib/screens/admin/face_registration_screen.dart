import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:flutter/foundation.dart'; // For kIsWeb
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

  @override
  void initState() {
    super.initState();
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

    _initializeControllerFuture = _controller!.initialize();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _handleRegisterFace() async {
    if (_imageFile == null) return;

    setState(() => _isLoading = true);
    
    // Simulate embedding extracting
    List<double> dummyEmbedding = List.generate(128, (index) => 0.5); 
    
    try {
      final token = await _apiService.getToken();
      if (token != null) {
        final result = await _apiService.registerFace(
          widget.userId, 
          dummyEmbedding, 
          'current_device_id', 
          token
        );

        final msg = result['msg']?.toString().toLowerCase() ?? '';
        if (result.containsKey('msg') && (msg.contains('success') || msg.contains('registered'))) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.translate('success'))),
          );
          
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.translate(result['msg'] ?? 'failure'))),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('error'))),
      );
    }
    setState(() => _isLoading = false);
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
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _imageFile == null
                            ? FutureBuilder<void>(
                                future: _initializeControllerFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.done) {
                                    return CameraPreview(_controller!);
                                  } else {
                                    return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                                  }
                                },
                              )
                            : kIsWeb 
                              ? Image.network(_imageFile!.path, fit: BoxFit.cover)
                              : Image.file(File(_imageFile!.path), fit: BoxFit.cover),
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
                          ? const CircularProgressIndicator(color: Colors.black)
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
