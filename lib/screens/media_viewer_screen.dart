import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatty/helper/dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MediaViewerScreen extends StatefulWidget {
  final String imageUrl;
  final String heroTag;
  final String title;
  final String timestamp;

  const MediaViewerScreen({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    required this.title,
    required this.timestamp,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen>
    with SingleTickerProviderStateMixin {
  late TransformationController _transformController;
  late AnimationController _springController;
  Animation<double>? _springAnimation;
  TapDownDetails? _doubleTapDetails;
  bool _showControls = true;
  double _dragOffset = 0.0;

  bool get _isAtDefaultScale =>
      _transformController.value.getMaxScaleOnAxis() <= 1.05;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..addListener(() {
        if (_springAnimation != null) {
          setState(() => _dragOffset = _springAnimation!.value);
        }
      });
  }

  @override
  void dispose() {
    _transformController.dispose();
    _springController.dispose();
    super.dispose();
  }

  void _springBack() {
    _springAnimation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOutCubic),
    );
    _springController.forward(from: 0.0);
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (!_isAtDefaultScale) {
      _transformController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      _transformController.value = Matrix4.diagonal3Values(2.5, 2.5, 1.0)
        ..setTranslationRaw(-position.dx * 1.5, -position.dy * 1.5, 0.0);
    }
    setState(() {});
  }

  Widget _buildErrorWidget() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.broken_image_rounded, size: 56, color: Colors.white54),
        const SizedBox(height: 12),
        Text(
          'Failed to load high-resolution image',
          style: TextStyle(
            fontFamily: 'Lexend',
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final double opacity = (1.0 - (_dragOffset.abs() / 320)).clamp(0.0, 1.0);
    final double scale = (1.0 - (_dragOffset.abs() / 900)).clamp(0.76, 1.0);
    final bool isDragging = _dragOffset.abs() > 15;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: opacity),
        body: Stack(
          children: [
            // Interactive Zoomable Photo with Smooth Physics Drag-to-Dismiss
            GestureDetector(
              onTap: () => setState(() => _showControls = !_showControls),
              onDoubleTapDown: _handleDoubleTapDown,
              onDoubleTap: _handleDoubleTap,
              onVerticalDragUpdate: _isAtDefaultScale
                  ? (details) {
                      setState(() {
                        _dragOffset += details.delta.dy;
                      });
                    }
                  : null,
              onVerticalDragEnd: _isAtDefaultScale
                  ? (details) {
                      final velocity = details.primaryVelocity?.abs() ?? 0;
                      if (_dragOffset.abs() > 110 || velocity > 750) {
                        Navigator.of(context).pop();
                      } else {
                        _springBack();
                      }
                    }
                  : null,
              child: Transform.translate(
                offset: Offset(0, _dragOffset),
                child: Transform.scale(
                  scale: scale,
                  child: Center(
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      minScale: 0.8,
                      maxScale: 4.0,
                      clipBehavior: Clip.none,
                      child: Hero(
                        tag: widget.heroTag,
                        child: widget.imageUrl.startsWith('http')
                            ? CachedNetworkImage(
                                imageUrl: widget.imageUrl,
                                fit: BoxFit.contain,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                errorWidget: (context, url, error) =>
                                    _buildErrorWidget(),
                              )
                            : Image.file(
                                File(widget.imageUrl),
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildErrorWidget(),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Top App Bar Controls (Hidden while dragging)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              top: (_showControls && !isDragging)
                  ? 0
                  : -(MediaQuery.of(context).padding.top + 90),
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 6,
                  bottom: 12,
                  left: 8,
                  right: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      splashRadius: 22,
                      tooltip: 'Back',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Lexend',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          if (widget.timestamp.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.timestamp,
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      splashRadius: 22,
                      tooltip: 'Copy Image Link',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: widget.imageUrl));
                        Dialogs.showSnackbar(
                            context, 'Image URL copied to clipboard!');
                      },
                      icon: const Icon(
                        Icons.link_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
