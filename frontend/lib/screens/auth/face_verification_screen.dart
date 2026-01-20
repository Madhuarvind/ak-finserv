import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../services/local_db_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart'; // To access cameras list

class FaceVerificationScreen extends StatefulWidget {
  final String userName;
  const FaceVerificationScreen({super.key, required this.userName});

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  CameraController? _controller;
  bool _isProcessing = false;
  final ApiService _apiService = ApiService();
  final LocalDbService _localDbService = LocalDbService();
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) {
      // Try fetching cameras again (common web issue)
      try {
        cameras = await availableCameras();
      } catch (e) {
        debugPrint("Re-fetch cameras failed: $e");
      }
    }

    if (cameras.isEmpty) {
      if (mounted) {
        setState(() => _statusMessage = "No camera found. Please enable permissions.");
      }
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
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Camera Error: $e");
      if (mounted) {
        setState(() => _statusMessage = "Camera initialization failed: $e");
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureAndVerify() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = "Analyzing face...";
    });
    
    try {
      final image = await _controller!.takePicture();
      final imageBytes = await image.readAsBytes();
      final deviceId = await _localDbService.getDeviceId();
      
      final result = await _apiService.verifyFaceLogin(
        widget.userName,
        imageBytes,
        deviceId
      );

      if (!mounted) return;

      if (result['msg'] == 'face_verified') {
        // Success -> Save tokens and navigate
        await _apiService.saveTokens(result['access_token'], result['refresh_token'] ?? '');
        await _apiService.saveUserData(widget.userName, result['role'] ?? 'field_agent');
        
        // Save locally too
        await _localDbService.saveUserLocally(
          name: widget.userName,
          pin: '****', // We don't have PIN here, store placeholder or fetch if needed
          token: result['access_token'],
          role: result['role'] ?? 'field_agent',
          isActive: true,
          isLocked: false,
        );
        
        setState(() => _statusMessage = "Verified! Redirecting...");
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (!mounted) return;
        if (result['role'] == 'admin') {
          Navigator.pushNamedAndRemoveUntil(context, '/admin/dashboard', (route) => false);
        } else {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
      } else {
        setState(() {
          final errorMsg = result['msg'] ?? "Verification failed";
          final details = result['error'] ?? result['details'] ?? "";
          _statusMessage = details.isNotEmpty ? "$errorMsg\n($details)" : errorMsg;
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint("FACE_DEBUG: Face Verification catch reached: $e");
      if (mounted) {
        setState(() {
          _statusMessage = "Critical Error: $e";
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Verification Error: $e"),
            duration: const Duration(seconds: 10),
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      if (_statusMessage != null) {
        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                Text(
                  _statusMessage!,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _initializeCamera,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                  child: Text("Retry Camera", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/home'), // Bypass for now? Or specific fallback?
                  child: const Text("Skip Verification (Dev Only)", style: TextStyle(color: Colors.white24)),
                )
              ],
            ),
          ),
        );
      }
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Full Screen Camera
          SizedBox.expand(
            child: CameraPreview(_controller!),
          ),
          
          // Overlay Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0F172A), // Dissolve into Deep Slate at top
                  Colors.transparent,
                  const Color(0xFF0F172A).withValues(alpha: 0.9), // Stronger fade at bottom
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.4, 1.0],
              )
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.security, color: AppTheme.primaryColor, size: 32),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Security Check",
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "New device detected. Verify face to continue.",
                        style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Status Message
                if (_statusMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      _statusMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),

                // Action Button
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _captureAndVerify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 8,
                        shadowColor: AppTheme.primaryColor.withValues(alpha: 0.4),
                      ),
                      child: _isProcessing 
                        ? const CircularProgressIndicator(color: Colors.black)
                        : Text("VERIFY IDENTITY", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
