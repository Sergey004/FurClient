import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fa_kit/fa_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/adaptive/adaptive.dart';
import '../services/fa_client.dart';
import '../services/download_service.dart';
import '../utils/fa_image_loader.dart';

class SubmissionCard extends StatefulWidget {
  final Submission submission;
  final FAClient client;
  final bool sfwMode;
  final VoidCallback onTap;
  final ValueChanged<Submission>? onFavoriteChanged;

  const SubmissionCard({
    super.key,
    required this.submission,
    required this.client,
    this.sfwMode = false,
    required this.onTap,
    this.onFavoriteChanged,
  });

  @override
  State<SubmissionCard> createState() => _SubmissionCardState();
}

class _SubmissionCardState extends State<SubmissionCard> {
  late Submission _current;
  bool _isFaving = false;

  @override
  void initState() {
    super.initState();
    _current = widget.submission;
  }

  @override
  void didUpdateWidget(covariant SubmissionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.submission != widget.submission) {
      _current = widget.submission;
    }
  }

  Future<void> _onFav() async {
    if (_isFaving) return;
    final wasFav = _current.isFavorite;
    // Optimistic update for instant, real-time feedback.
    setState(() {
      _isFaving = true;
      _current = _current.copyWith(
        isFavorite: !wasFav,
        faves: _current.faves + (wasFav ? -1 : 1),
      );
    });
    try {
      final updated = _current.favoriteUrl.isNotEmpty
          ? await widget.client
              .toggleFavorite(_current.favoriteUrl, _current.id)
          : await widget.client.toggleFavoriteById(_current.id);
      if (!mounted) return;
      if (updated != null) {
        // Reconcile with the server's parsed state.
        setState(() => _current = updated);
        widget.onFavoriteChanged?.call(updated);
        await _maybeAutoDownload();
      } else {
        // Site toggle failed — revert the optimistic change.
        setState(() {
          _current = _current.copyWith(
            isFavorite: wasFav,
            faves: _current.faves + (wasFav ? 1 : -1),
          );
        });
      }
    } finally {
      if (mounted) setState(() => _isFaving = false);
    }
  }

  /// Mirror the detail screen: when the user faves a post and the
  /// `auto_download_on_fave` setting is enabled, download the image.
  Future<void> _maybeAutoDownload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoDownload = prefs.getBool('auto_download_on_fave') ?? false;
      if (!autoDownload) return;
      final sub = _current;
      if (sub.imageUrl.isEmpty) return;
      final path = await DownloadService.instance.downloadImage(
        imageUrl: sub.imageUrl,
        title: sub.title,
        author: sub.author,
        rating: sub.rating,
      );
      if (mounted) {
        if (path != null) {
          debugPrint('=== card auto-download saved: ${path.split('/').last}');
        } else {
          debugPrint('=== card auto-download failed');
        }
      }
    } catch (e) {
      debugPrint('=== card auto-download error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: _current.isFavorite
              ? BorderSide(color: AppColors.notifFave, width: 2)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildImage()),
            _buildCaption(),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
          child: _current.imageUrl.isNotEmpty
              ? FAImage(
                  url: _current.imageUrl,
                  dynamicThumbnail: DynamicThumbnail(
                    Uri.parse(_current.imageUrl),
                  ),
                  fit: BoxFit.cover,
                  placeholder: Container(
                    color: AppColors.bgInput,
                    child: const Center(
                      child: AdaptiveProgress(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: Container(
                    color: AppColors.bgInput,
                    child: const Icon(
                      Icons.broken_image,
                      color: AppColors.textMuted,
                      size: 32,
                    ),
                  ),
                )
              : Container(
                  color: AppColors.bgInput,
                  child: const Icon(
                    Icons.image,
                    color: AppColors.textMuted,
                    size: 32,
                  ),
                ),
        ),
        if (_current.isNsfw && widget.sfwMode)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: AppColors.bgCard.withValues(alpha: 0.7),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility_off,
                        color: AppColors.textMuted,
                        size: 28,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'NSFW',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _onFav,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.bgCard.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: _isFaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: AdaptiveProgress(
                          strokeWidth: 2,
                          color: AppColors.notifFave,
                        ),
                      )
                    : Icon(
                        _current.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: _current.isFavorite
                            ? AppColors.notifFave
                            : AppColors.textDim,
                        size: 18,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaption() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _current.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
          if (_current.author.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              _current.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
