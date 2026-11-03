part of 'log_center_panel.dart';

/// Error screenshot preview with log-folder and download actions.
class LogCenterErrorImageCard extends StatelessWidget {
  /// Creates one error screenshot card.
  const LogCenterErrorImageCard({
    super.key,
    required this.controller,
    required this.detail,
  });

  /// Log browser controller.
  final ScriptLogBrowserController controller;

  /// Error detail owning the screenshots.
  final ScriptErrorLogDetail detail;

  static const double _previewHeight = 180;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final images = detail.images;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.photo_outlined, size: 20, color: colors.primary),
            const SizedBox(width: 8),
            Text(
              I18n.homeLogErrorScreenshot.tr,
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (images.isEmpty)
          _buildPlaceholder(theme, colors)
        else
          for (final image in images)
            Padding(
              padding: EdgeInsets.only(bottom: image == images.last ? 0 : 8),
              child: _buildPreview(context, image, colors),
            ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildOpenFolderButton()),
            const SizedBox(width: 8),
            Expanded(child: _buildDownloadButton(images)),
          ],
        ),
      ],
    );
  }

  /// Builds the empty state shown when the error has no screenshot.
  Widget _buildPlaceholder(ThemeData theme, ColorScheme colors) {
    return Container(
      height: _previewHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hide_image_outlined,
            size: 28,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            I18n.homeLogNoScreenshot.tr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds one screenshot preview that opens the full-screen viewer.
  Widget _buildPreview(
    BuildContext context,
    ScriptErrorImageInfo image,
    ColorScheme colors,
  ) {
    final url = ApiClient().buildScriptErrorImageUrl(detail.id, image.name);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: colors.surfaceContainerHighest,
        child: InkWell(
          onTap: () => LogCenterErrorImageViewer.show(
            context,
            url: url,
            title: image.name,
          ),
          child: SizedBox(
            height: _previewHeight,
            width: double.infinity,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) {
                  return child;
                }
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stackTrace) => Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the button that reveals the error log folder.
  Widget _buildOpenFolderButton() {
    return OutlinedButton.icon(
      onPressed: controller.openErrorLogDirectory,
      icon: const Icon(Icons.folder_open_rounded, size: 18),
      label: Text(
        I18n.homeLogOpenLogFolder.tr,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Builds the per-image download button with loading feedback.
  Widget _buildDownloadButton(List<ScriptErrorImageInfo> images) {
    if (images.isEmpty) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.download_rounded, size: 18),
        label: Text(
          I18n.homeLogDownloadScreenshot.tr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    final image = images.first;
    return Obx(() {
      final loading = controller.isErrorImageDownloading(image);
      return FilledButton.tonalIcon(
        onPressed: loading ? null : () => controller.downloadErrorImage(image),
        icon: loading
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_rounded, size: 18),
        label: Text(
          I18n.homeLogDownloadScreenshot.tr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    });
  }
}
