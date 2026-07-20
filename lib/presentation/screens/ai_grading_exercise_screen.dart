import 'dart:async';
import 'dart:typed_data';
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

    // Lock orientation to Landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
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

      // Start processing frames
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
    if (_isProcessingFrame || _isAnalyzing || _showGuideModal) return;
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
      if (mounted && features.isNotEmpty) {
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
    int idY = numPixels;
    final uRowStride = uPlane.bytesPerRow;
    final vRowStride = vPlane.bytesPerRow;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;

    for (int y = 0; y < height / 2; y++) {
      for (int x = 0; x < width / 2; x++) {
        final uIndex = y * uRowStride + x * uPixelStride;
        final vIndex = y * vRowStride + x * vPixelStride;

        if (vIndex < vBuffer.length && uIndex < uBuffer.length) {
          nv21[idY++] = vBuffer[vIndex];
          nv21[idY++] = uBuffer[uIndex];
        }
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
        return InputImageRotation.rotation0deg;
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _animationController.dispose();
    _analysisTimer?.cancel();
    _processor.close();

    // Restore orientation to Portrait
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  void _onSubmitExercise() {
    setState(() {
      _isAnalyzing = true;
    });

    _deinitializeCamera();

    // Request final polished sentence/translation
    context.read<GestureBloc>().add(GesturePolishRequested());
    
    // Simulate 2 seconds of analysis before navigating to results
    _analysisTimer = Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      
      // Temporarily restore to portrait before push
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiGradingScoreScreen(lesson: widget.lesson),
        ),
      );

      if (!mounted) return;
      if (result != null) {
        Navigator.pop(context, result);
      } else {
        // Returned without submit, lock back to landscape
        setState(() {
          _isAnalyzing = false;
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

    // Mirroring front camera preview
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.rotationY(3.14159265), // Mirror horizontally for selfie view
      child: CameraPreview(_cameraController!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final textTheme = Theme.of(context).textTheme;
    final isLandscape = size.width > size.height;

    // Use a responsive layout based on screen orientation
    Widget content;
    if (isLandscape) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Camera Viewport (16:9 box)
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildCameraView(size),
                    // Scan animation line inside viewfinder
                    Align(
                      alignment: const Alignment(0, 0),
                      child: Container(
                        width: size.width * 0.4,
                        height: size.height * 0.6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4), width: 1.5),
                        ),
                        child: Stack(
                          children: [
                            Positioned(top: -2, left: -2, child: Container(width: 8, height: 8, decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.primaryColor, width: 2), left: BorderSide(color: AppTheme.primaryColor, width: 2))))),
                            Positioned(top: -2, right: -2, child: Container(width: 8, height: 8, decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.primaryColor, width: 2), right: BorderSide(color: AppTheme.primaryColor, width: 2))))),
                            Positioned(bottom: -2, left: -2, child: Container(width: 8, height: 8, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.primaryColor, width: 2), left: BorderSide(color: AppTheme.primaryColor, width: 2))))),
                            Positioned(bottom: -2, right: -2, child: Container(width: 8, height: 8, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.primaryColor, width: 2), right: BorderSide(color: AppTheme.primaryColor, width: 2))))),
                            AnimatedBuilder(
                              animation: _scanAnimation,
                              builder: (context, child) {
                                return Positioned(
                                  top: (size.height * 0.6) * _scanAnimation.value,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 1.5,
                                    decoration: BoxDecoration(
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primaryColor.withOpacity(0.6),
                                          blurRadius: 4,
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
                    // Status overlay
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isAnalyzing ? AppTheme.primaryColor : const Color(0xFFE46C6C),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isAnalyzing ? 'Đang chấm điểm...' : 'AI Camera Đang Hoạt Động',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Right: AI Control & Recognition Output Panel
          Expanded(
            flex: 2,
            child: AppTheme.glassPanel(
              borderRadius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Bài tập ký hiệu:',
                    style: textTheme.bodyMedium?.copyWith(color: AppTheme.onSurfaceVariant, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.lesson.title,
                    style: textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(height: 1, color: Colors.white.withOpacity(0.1)),
                  const SizedBox(height: 6),
                  Expanded(
                    child: BlocBuilder<GestureBloc, GestureState>(
                      builder: (context, state) {
                        List<String> words = [];
                        int captured = 0;
                        double confidence = 0.0;
                        String current = '';
                        
                        if (state is GestureBufferUpdating) {
                          words = state.recognizedWords;
                          captured = state.capturedFrames;
                        } else if (state is GesturePredictionSuccess) {
                          words = state.recognizedWords;
                          captured = state.capturedFrames;
                          confidence = state.confidence;
                          current = state.predictedWord;
                        } else if (state is GestureTranslationSuccess) {
                          words = state.recognizedWords;
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Kết quả nhận diện thực tế (AI):',
                              style: textTheme.bodyMedium?.copyWith(color: AppTheme.onSurfaceVariant, fontSize: 11),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (words.isEmpty && current.isEmpty)
                                        const Text(
                                          'Chưa ghi nhận cử chỉ. Hãy bắt đầu thực hiện ký hiệu...',
                                          style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic, fontSize: 12),
                                        )
                                      else ...[
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: words.map((w) => Chip(
                                            label: Text(w, style: const TextStyle(color: Colors.white, fontSize: 11)),
                                            backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                                            side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.4)),
                                            padding: EdgeInsets.zero,
                                            visualDensity: VisualDensity.compact,
                                          )).toList(),
                                        ),
                                        if (current.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            'Từ vừa thực hiện: $current (${(confidence * 100).toStringAsFixed(0)}%)',
                                            style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ]
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Buffering frame status
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Tín hiệu cử chỉ:', style: TextStyle(color: Colors.white60, fontSize: 10)),
                                Text('$captured/${GestureBloc.targetFrameCount} frames', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 3),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: captured / GestureBloc.targetFrameCount,
                                minHeight: 4,
                                backgroundColor: Colors.white10,
                                valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isAnalyzing ? null : _onSubmitExercise,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: AppTheme.onPrimaryContainer,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isAnalyzing
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(AppTheme.onPrimaryContainer),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Nộp bài & Chấm điểm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward_rounded, size: 14),
                            ],
                          ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _isAnalyzing ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withOpacity(0.1)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Thoát', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      // Portrait Fallback - Prompt rotation
      content = Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: AppTheme.glassPanel(
            borderRadius: 24,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.screen_rotation_rounded, color: AppTheme.primaryColor, size: 64),
                const SizedBox(height: 20),
                const Text(
                  'Vui lòng xoay ngang điện thoại',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ứng dụng nhận diện AI yêu cầu thiết bị ở chế độ nằm ngang để tối ưu hóa góc ghi hình camera 16:9.',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    SystemChrome.setPreferredOrientations([
                      DeviceOrientation.landscapeLeft,
                      DeviceOrientation.landscapeRight,
                    ]);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: AppTheme.onPrimaryContainer,
                  ),
                  child: const Text('Ép buộc xoay ngang'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.onSurfaceVariant),
          onPressed: () => Navigator.pop(context),
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
        ],
      ),
    );
  }
}
