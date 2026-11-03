part of 'log_center_panel.dart';

/// Full-screen viewer for one error screenshot.
///
/// The initial scale is 100%: one source pixel maps to one Flutter logical
/// pixel, so no device pixel ratio compensation is applied.
class LogCenterErrorImageViewer extends StatefulWidget {
  /// Creates one error screenshot viewer.
  const LogCenterErrorImageViewer({
    super.key,
    required this.url,
    required this.title,
  });

  /// Network address of the screenshot.
  final String url;

  /// Caption rendered in the viewer header.
  final String title;

  /// Opens the viewer as a full-screen dialog.
  static Future<void> show(
    BuildContext context, {
    required String url,
    required String title,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .86),
      builder: (_) => LogCenterErrorImageViewer(url: url, title: title),
    );
  }

  @override
  State<LogCenterErrorImageViewer> createState() =>
      _LogCenterErrorImageViewerState();
}

class _LogCenterErrorImageViewerState extends State<LogCenterErrorImageViewer> {
  final TransformationController _transform = TransformationController();
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _imageSize;
  Size? _viewport;
  Object? _loadError;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void dispose() {
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _transform.dispose();
    super.dispose();
  }

  /// Resolves the intrinsic image size once so the 100% matrix can be built.
  void _resolveImage() {
    if (_requested) {
      return;
    }
    _requested = true;
    final stream = NetworkImage(
      widget.url,
    ).resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener(
      (info, _) {
        if (!mounted) {
          return;
        }
        final scale = info.scale <= 0 ? 1.0 : info.scale;
        setState(() {
          _imageSize = Size(
            info.image.width / scale,
            info.image.height / scale,
          );
        });
        _applyFit();
      },
      onError: (error, _) {
        if (!mounted) {
          return;
        }
        setState(() => _loadError = error);
      },
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  /// Centers the screenshot at 100% inside the current viewport.
  void _applyFit() {
    final size = _imageSize;
    final viewport = _viewport;
    if (size == null || viewport == null) {
      return;
    }
    _transform.value = Matrix4.identity()
      ..setTranslationRaw(
        (viewport.width - size.width) / 2,
        (viewport.height - size.height) / 2,
        0,
      );
  }

  void _close() {
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        const SingleActivator(LogicalKeyboardKey.digit0): _applyFit,
      },
      child: Focus(
        autofocus: true,
        child: Dialog.fullscreen(
          backgroundColor: const Color(0xFF0B0B0D),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildViewport()),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          const Icon(Icons.image_outlined, size: 20, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ValueListenableBuilder<Matrix4>(
            valueListenable: _transform,
            builder: (context, matrix, _) {
              final percent = (matrix.getMaxScaleOnAxis() * 100).round();
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$percent%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: I18n.homeLogImageViewerReset.tr,
            onPressed: _applyFit,
            color: Colors.white70,
            icon: const Icon(Icons.restart_alt_rounded, size: 20),
          ),
          IconButton(
            tooltip: I18n.back.tr,
            onPressed: _close,
            color: Colors.white70,
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildViewport() {
    if (_loadError != null) {
      return Center(
        child: Text(
          I18n.homeLogNoScreenshot.tr,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
    final size = _imageSize;
    if (size == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        if (_viewport != viewport) {
          _viewport = viewport;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _applyFit();
            }
          });
        }
        return GestureDetector(
          onDoubleTap: _applyFit,
          child: InteractiveViewer(
            transformationController: _transform,
            constrained: false,
            minScale: .05,
            maxScale: 8,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: Image.network(
                widget.url,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: Colors.white54,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              I18n.homeLogImageViewerHint.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
