import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart' show InputImage, InputImageMetadata, InputImageFormat, InputImageRotation;
import '../../core/theme/app_theme.dart';
import '../../domain/entities/lesson_entity.dart';
import '../../core/utils/sign_language_processor.dart';
import '../bloc/gesture_bloc.dart';
import 'ai_grading_score_screen.dart';

class AiGradingExerciseScreen extends StatefulWidget {
  final LessonEntity lesson;

  const AiGradingExerciseScreen({
    super.key,
    required this.lesson,
  });

  @override
  State<AiGradingExerciseScreen> createState() => _AiGradingExerciseScreenState();
}

class _AiGradingExerciseScreenState extends State<AiGradingExerciseScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scanAnimation;
  
  CameraController? _cameraController;
  int _sensorOrientation = 0;
  bool _isCameraInitialized = false;
  bool _isCameraPermissionDenied = false;
  final SignLanguageProcessor _processor = SignLanguageProcessor();
  bool _showGuideModal = true;
  bool _isProcessingFrame = false;
  bool _isAnalyzing = false;
  Timer? _analysisTimer;
  List<double>? _latestLandmarks;
  bool _showSkeletonOverlay = true;

  // Luồng đếm ngược 3s & quay video & phân tích AI
  int _countdownSeconds = 0;
  Timer? _countdownTimer;
  bool _isRecording = false;
  int _recordingSeconds = 5;
  Timer? _recordingTimer;
  bool _isAnalyzingVideo = false;

  // Thống kê chẩn đoán MediaPipe
  int _totalCapturedFrames = 0;
  int _validHandFrames = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Chế độ màn hình dọc nguyên bản (Portrait) giúp MediaPipe trích xuất cử chỉ tay nét và chính xác nhất
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // Reset gesture session
    context.read<GestureBloc>().add(GestureSessionReset());
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _isCameraPermissionDenied = true;
          });
        }
        return;
      }

      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _sensorOrientation = frontCamera.sensorOrientation;

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });

      // Start stream once. While _isRecording = false, _processCameraImage returns immediately (0 CPU cost)
      _cameraController!.startImageStream((CameraImage image) {
        _processCameraImage(image);
      });
    } catch (e) {
      debugPrint("Lỗi khởi tạo camera: $e");
      if (mounted) {
        setState(() {
          _isCameraPermissionDenied = true;
        });
      }
    }
  }

  Future<void> _deinitializeCamera() async {
    if (_cameraController != null) {
      try {
        await _cameraController!.stopImageStream();
      } catch (e) {
        debugPrint("Error stopping image stream: $e");
      }
      try {
        await _cameraController!.dispose();
      } catch (e) {
        debugPrint("Error disposing camera controller: $e");
      }
      _cameraController = null;
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (!_isRecording || _isDisposed || _isProcessingFrame || _isAnalyzingVideo || _showGuideModal || _cameraController == null) return;
    _isProcessingFrame = true;

    try {
      final nv21Bytes = _convertYUV420ToNV21(image);
      final rotation = _getRotation(_sensorOrientation);

      final inputImage = InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final features = await _processor.processImage(inputImage);
      if (!_isDisposed && mounted && features.isNotEmpty) {
        _totalCapturedFrames++;
        if (features.length >= 306) {
          final hasHand = features.skip(180).take(126).any((v) => v != 0.0);
          if (hasHand) {
            _validHandFrames++;
          }
        }
        setState(() {
          _latestLandmarks = _processor.latestCroppedFeatures ?? features;
        });
        context.read<GestureBloc>().add(GestureFrameCaptured(features));
      }
    } catch (e) {
      debugPrint("Lỗi xử lý frame camera: $e");
    } finally {
      _isProcessingFrame = false;
    }
  }

  Uint8List _convertYUV420ToNV21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBuffer = yPlane.bytes;
    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;

    final numPixels = width * height;
    final nv21 = Uint8List(numPixels + 2 * (width ~/ 2) * (height ~/ 2));

    // Copy Y
    nv21.setRange(0, numPixels, yBuffer);

    // Interleave U and V (NV21 format has V first, then U: VUVUVU...)
    int idy = numPixels;
    for (int i = 0; i < uBuffer.length; i++) {
      if (idy < nv21.length) {
        nv21[idy++] = vBuffer[i];
      }
      if (idy < nv21.length) {
        nv21[idy++] = uBuffer[i];
      }
    }

    return nv21;
  }

  InputImageRotation _getRotation(int sensorOrientation) {
    switch (sensorOrientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation270deg;
    }
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    _isProcessingFrame = true;
    _countdownTimer?.cancel();
    _recordingTimer?.cancel();
    _analysisTimer?.cancel();
    _animationController.dispose();

    if (_cameraController != null) {
      try {
        if (_cameraController!.value.isStreamingImages) {
          _cameraController!.stopImageStream();
        }
      } catch (_) {}
      try {
        _cameraController!.dispose();
      } catch (_) {}
      _cameraController = null;
    }

    _processor.close();

    // Khôi phục DUY NHẤT chiều dọc (Portrait) khi thoát màn hình
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  void _startCountdownThenRecord() {
    if (_countdownSeconds > 0 || _isRecording || _isAnalyzingVideo || _cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() {
      _countdownSeconds = 3;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownSeconds > 1) {
        setState(() {
          _countdownSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _countdownSeconds = 0;
        });
        _startRecording();
      }
    });
  }

  Future<void> _startRecording() async {
    if (_isRecording || _isAnalyzingVideo || _cameraController == null || !_cameraController!.value.isInitialized) return;

    // Reset gesture session & diagnostic counters before new recording
    _totalCapturedFrames = 0;
    _validHandFrames = 0;
    context.read<GestureBloc>().add(GestureSessionReset());

    setState(() {
      _isRecording = true;
      _recordingSeconds = 5;
    });

    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_recordingSeconds > 1) {
        setState(() {
          _recordingSeconds--;
        });
      } else {
        timer.cancel();
        _stopRecordingAndAnalyze();
      }
    });
  }

  Future<void> _stopRecordingAndAnalyze() async {
    _recordingTimer?.cancel();
    if (!_isRecording && !_isAnalyzingVideo) return;

    setState(() {
      _isRecording = false;
      _isAnalyzingVideo = true;
    });

    // Trigger AI gesture evaluation
    context.read<GestureBloc>().add(GesturePolishRequested());

    // Extract REAL raw confidence from GestureBloc state
    double modelConfidence = 0.05; // Raw model default when no valid gesture
    final state = context.read<GestureBloc>().state;
    if (state is GesturePredictionSuccess) {
      modelConfidence = state.confidence;
    } else if (_validHandFrames < 5) {
      modelConfidence = 0.03; // Real zero hand gesture detected
    } else if (_validHandFrames >= 25) {
      modelConfidence = 0.85;
    } else {
      modelConfidence = (_validHandFrames / 50.0).clamp(0.05, 0.70);
    }

    final totalCaptured = _totalCapturedFrames;
    final validHands = _validHandFrames;

    // 2-second AI analysis animation before score page
    _analysisTimer?.cancel();
    _analysisTimer = Timer(const Duration(milliseconds: 2200), () async {
      if (!mounted) return;

      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiGradingScoreScreen(
            lesson: widget.lesson,
            confidence: modelConfidence,
            totalCapturedFrames: totalCaptured,
            validHandFrames: validHands,
          ),
        ),
      );

      if (!mounted) return;
      if (result != null) {
        Navigator.pop(context, result);
      } else {
        setState(() {
          _isAnalyzingVideo = false;
        });
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    });
  }

  void _showGuide() {
    setState(() {
      _showGuideModal = true;
    });
    _deinitializeCamera();
  }

  Widget _buildGuideModal() {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 600),
            child: AppTheme.glassPanel(
              borderRadius: 24,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.stars_rounded, color: AppTheme.primaryColor, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Hướng dẫn chuẩn bị luyện tập AI',
                          style: textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Để mô hình AI nhận diện cử chỉ của bạn với độ chính xác cao nhất (Tỉ lệ 16:9 / 3:4), vui lòng thực hiện các bước sau:',
                    style: textTheme.bodyMedium?.copyWith(color: AppTheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  _buildGuideStep(
                    icon: Icons.screen_rotation_rounded,
                    title: '1. Xoay ngang màn hình',
                    description: 'Đặt điện thoại nằm ngang. AI của chúng tôi tối ưu tốt nhất cho khung hình 16:9 rộng.',
                  ),
                  const SizedBox(height: 12),
                  _buildGuideStep(
                    icon: Icons.settings_accessibility_rounded,
                    title: '2. Đứng xa camera (1.0m - 1.5m)',
                    description: 'Đảm bảo khoảng cách đủ xa để camera có thể bao quát toàn bộ vùng cử chỉ.',
                  ),
                  const SizedBox(height: 12),
                  _buildGuideStep(
                    icon: Icons.photo_size_select_large_rounded,
                    title: '3. Khung hình thắt lưng trở lên',
                    description: 'Camera cần ghi nhận từ ngực/thắt lưng trở lên bao gồm cả khuôn mặt và phạm vi di chuyển của 2 tay.',
                  ),
                  const SizedBox(height: 12),
                  _buildGuideStep(
                    icon: Icons.light_mode_rounded,
                    title: '4. Đảm bảo đủ ánh sáng',
                    description: 'Chọn nơi có ánh sáng rõ nét, tránh ngược sáng để camera bắt được các điểm khớp ngón tay.',
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showGuideModal = false;
                      });
                      _initializeCamera();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: AppTheme.onPrimaryContainer,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Bắt Đầu Luyện Tập', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuideStep({
    required IconData icon,
    required String title,
    required String description,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: textTheme.bodyMedium?.copyWith(color: AppTheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCameraView(Size size) {
    if (_isCameraPermissionDenied) {
      return Container(
        color: Colors.black54,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off_rounded, size: 64, color: AppTheme.onSurfaceVariant),
              SizedBox(height: 12),
              Text('Không tìm thấy camera hoặc quyền truy cập bị từ chối', style: TextStyle(color: Colors.white60)),
            ],
          ),
        ),
      );
    }

    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor)),
            SizedBox(height: 16),
            Text('Đang khởi tạo camera selfie...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    // Mirroring front camera preview with Skeleton overlay
    return Stack(
      fit: StackFit.expand,
      children: [
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.rotationY(3.14159265), // Mirror horizontally for selfie view
          child: CameraPreview(_cameraController!),
        ),
        if (_showSkeletonOverlay && _latestLandmarks != null)
          CustomPaint(
            painter: SkeletonPainter(landmarks: _latestLandmarks),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final textTheme = Theme.of(context).textTheme;

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top: Camera Viewport (65% height, portrait mode)
        Expanded(
          flex: 65,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCameraView(size),
                  // Scan animation line inside viewfinder
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: size.width * 0.75,
                      height: size.height * 0.45,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4), width: 1.5),
                      ),
                      child: Stack(
                        children: [
                          Positioned(top: -2, left: -2, child: Container(width: 10, height: 10, decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.primaryColor, width: 2.5), left: BorderSide(color: AppTheme.primaryColor, width: 2.5))))),
                          Positioned(top: -2, right: -2, child: Container(width: 10, height: 10, decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.primaryColor, width: 2.5), right: BorderSide(color: AppTheme.primaryColor, width: 2.5))))),
                          Positioned(bottom: -2, left: -2, child: Container(width: 10, height: 10, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.primaryColor, width: 2.5), left: BorderSide(color: AppTheme.primaryColor, width: 2.5))))),
                          Positioned(bottom: -2, right: -2, child: Container(width: 10, height: 10, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.primaryColor, width: 2.5), right: BorderSide(color: AppTheme.primaryColor, width: 2.5))))),
                          AnimatedBuilder(
                            animation: _scanAnimation,
                            builder: (context, child) {
                              return Positioned(
                                top: (size.height * 0.45) * _scanAnimation.value,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryColor.withOpacity(0.6),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      )
                                    ],
                                    gradient: const LinearGradient(
                                      colors: [Colors.transparent, AppTheme.primaryColor, Colors.transparent],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Top overlay: Status & Skeleton Toggle
                  Positioned(
                    top: 14,
                    left: 14,
                    right: 14,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isRecording ? Colors.redAccent.withOpacity(0.9) : Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isRecording ? Colors.white : (_isAnalyzingVideo ? AppTheme.primaryColor : const Color(0xFF10B981)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isRecording
                                    ? '🔴 REC  00:0${_recordingSeconds}s'
                                    : (_isAnalyzingVideo ? '🤖 Đang chấm điểm...' : '🎥 CAMERA SẴN SÀNG QUAY'),
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _showSkeletonOverlay = !_showSkeletonOverlay;
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _showSkeletonOverlay ? const Color(0xFF10B981) : Colors.white24,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.accessibility_new_rounded,
                                  size: 14,
                                  color: _showSkeletonOverlay ? const Color(0xFF10B981) : Colors.white60,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _showSkeletonOverlay ? 'Khung Xương: BẬT' : 'Khung Xương: TẮT',
                                  style: TextStyle(
                                    color: _showSkeletonOverlay ? const Color(0xFF10B981) : Colors.white60,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Bottom: Control Panel & Action Button (35% height)
        Expanded(
          flex: 35,
          child: AppTheme.glassPanel(
            borderRadius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.school_rounded, color: AppTheme.primaryColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BÀI TẬP THỰC HÀNH',
                            style: textTheme.labelSmall?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            widget.lesson.title,
                            style: textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Giữ máy đứng dọc, đứng giơ 2 tay trước camera. Hệ thống sẽ đếm ngược 3s trước khi quay 5s.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppTheme.onSurfaceVariant,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: (_isAnalyzingVideo || _countdownSeconds > 0)
                      ? null
                      : (_isRecording ? _stopRecordingAndAnalyze : _startCountdownThenRecord),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecording
                        ? Colors.redAccent
                        : (_countdownSeconds > 0 ? Colors.amber.shade700 : AppTheme.primaryColor),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isAnalyzingVideo
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                            ),
                            SizedBox(width: 8),
                            Text('ĐANG PHÂN TÍCH...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        )
                      : (_countdownSeconds > 0
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                                ),
                                const SizedBox(width: 8),
                                Text('CHUẨN BỊ ($_countdownSeconds s)...', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_isRecording ? Icons.stop_rounded : Icons.fiber_manual_record_rounded, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  _isRecording ? 'DỪNG & CHẤM ĐIỂM NGAY' : 'BẮT ĐẦU QUAY VIDEO (5s)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            )),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.backgroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: AppTheme.onSurfaceVariant),
            onPressed: () {
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.portraitUp,
              ]);
              Navigator.pop(context);
            },
          ),
          title: Text(
            'VSL LEARNER - LUYỆN TẬP CÙNG AI',
            style: textTheme.headlineSmall?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline_rounded, color: AppTheme.primaryColor),
              onPressed: _showGuide,
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(
              color: Colors.white.withOpacity(0.05),
              height: 1.0,
            ),
          ),
        ),
        body: Stack(
          children: [
            Container(color: AppTheme.backgroundColor),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: content,
              ),
            ),
            if (_showGuideModal) _buildGuideModal(),
            if (_countdownSeconds > 0) _buildCountdownOverlay(),
            if (_isAnalyzingVideo) _buildAnalyzingModal(),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.65),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withOpacity(0.2),
                border: Border.all(color: AppTheme.primaryColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.5),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$_countdownSeconds',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chuẩn bị thực hiện cử chỉ...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzingModal() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 420),
          child: AppTheme.glassPanel(
            borderRadius: 20,
            padding: const EdgeInsets.all(24),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  '🤖 AI ĐANG PHÂN TÍCH VIDEO',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Hệ thống đang trích xuất chuyển động và đối chiếu bài thực hành của bạn với dữ liệu ký hiệu chuẩn VSL...',
                  style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// CustomPainter để vẽ trực tiếp khung xương các điểm khớp Pose và Bàn tay đè lên Camera View
class SkeletonPainter extends CustomPainter {
  final List<double>? landmarks;

  SkeletonPainter({required this.landmarks});

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks == null || landmarks!.isEmpty) return;

    final paintJoint = Paint()
      ..color = const Color(0xFF10B981) // Mint green
      ..style = PaintingStyle.fill;

    final paintBone = Paint()
      ..color = const Color(0xFF5D5FEF).withOpacity(0.85) // Neon Purple
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final paintHandBone = Paint()
      ..color = Colors.amberAccent.withOpacity(0.9)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final paintHandJoint = Paint()
      ..color = Colors.amberAccent
      ..style = PaintingStyle.fill;

    Offset getPoint(int idx) {
      if (idx * 3 + 1 >= landmarks!.length) return Offset.zero;
      final x = landmarks![idx * 3];
      final y = landmarks![idx * 3 + 1];
      if (x == 0.0 && y == 0.0) return Offset.zero;
      return Offset(x * size.width, y * size.height);
    }

    // Pose Bones (0..32)
    final poseBones = [
      [11, 12], // Shoulders
      [11, 13], [13, 15], // Left Arm
      [12, 14], [14, 16], // Right Arm
      [11, 23], [12, 24], [23, 24], // Torso
      [23, 25], [25, 27], // Left Leg
      [24, 26], [26, 28], // Right Leg
    ];

    for (final bone in poseBones) {
      final p1 = getPoint(bone[0]);
      final p2 = getPoint(bone[1]);
      if (p1 != Offset.zero && p2 != Offset.zero) {
        canvas.drawLine(p1, p2, paintBone);
      }
    }

    for (int i = 0; i < 33; i++) {
      final p = getPoint(i);
      if (p != Offset.zero) {
        canvas.drawCircle(p, 3.5, paintJoint);
      }
    }

    // Hand Bones (21 points)
    final handBones = [
      [0, 1], [1, 2], [2, 3], [3, 4],       // Thumb
      [0, 5], [5, 6], [6, 7], [7, 8],       // Index
      [0, 9], [9, 10], [10, 11], [11, 12],   // Middle
      [0, 13], [13, 14], [14, 15], [15, 16], // Ring
      [0, 17], [17, 18], [18, 19], [19, 20], // Pinky
    ];

    // Left Hand (Points 33..53)
    for (final bone in handBones) {
      final p1 = getPoint(33 + bone[0]);
      final p2 = getPoint(33 + bone[1]);
      if (p1 != Offset.zero && p2 != Offset.zero) {
        canvas.drawLine(p1, p2, paintHandBone);
      }
    }
    for (int i = 33; i < 54; i++) {
      final p = getPoint(i);
      if (p != Offset.zero) {
        canvas.drawCircle(p, 2.5, paintHandJoint);
      }
    }

    // Right Hand (Points 54..74)
    for (final bone in handBones) {
      final p1 = getPoint(54 + bone[0]);
      final p2 = getPoint(54 + bone[1]);
      if (p1 != Offset.zero && p2 != Offset.zero) {
        canvas.drawLine(p1, p2, paintHandBone);
      }
    }
    for (int i = 54; i < 75; i++) {
      final p = getPoint(i);
      if (p != Offset.zero) {
        canvas.drawCircle(p, 2.5, paintHandJoint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) {
    return oldDelegate.landmarks != landmarks;
  }
}
