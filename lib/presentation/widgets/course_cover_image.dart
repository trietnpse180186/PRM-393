import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/usecases/learning/fetch_video_url_usecase.dart';

class CourseCoverImage extends StatefulWidget {
  final int? coverMediaId;
  final String defaultImageUrl;
  final BoxFit fit;

  const CourseCoverImage({
    super.key,
    required this.coverMediaId,
    required this.defaultImageUrl,
    this.fit = BoxFit.cover,
  });

  @override
  State<CourseCoverImage> createState() => _CourseCoverImageState();
}

class _CourseCoverImageState extends State<CourseCoverImage> {
  String? _resolvedUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _resolveUrl();
  }

  @override
  void didUpdateWidget(covariant CourseCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverMediaId != widget.coverMediaId) {
      _resolveUrl();
    }
  }

  Future<void> _resolveUrl() async {
    if (widget.coverMediaId == null) {
      if (mounted) {
        setState(() {
          _resolvedUrl = null;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final fetchVideoUrlUseCase = context.read<FetchVideoUrlUseCase>();
      final url = await fetchVideoUrlUseCase(widget.coverMediaId!);
      if (mounted) {
        setState(() {
          _resolvedUrl = url;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: AppTheme.surfaceContainer,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
            ),
          ),
        ),
      );
    }

    final url = _resolvedUrl ?? widget.defaultImageUrl;
    
    // Check if it's a network URL or fallback asset/local resource (if applicable)
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => Container(
          color: AppTheme.surfaceContainerHighest,
          child: const Icon(
            Icons.menu_book_rounded,
            size: 48,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
      );
    } else {
      // Local asset/placeholder fallback
      return Image.network(
        widget.defaultImageUrl,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => Container(
          color: AppTheme.surfaceContainerHighest,
          child: const Icon(
            Icons.menu_book_rounded,
            size: 48,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
      );
    }
  }
}
