import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fa_kit/fa_kit.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/adaptive/adaptive.dart';
import '../services/fa_client.dart';
import '../utils/fa_image_loader.dart';

class SubmissionCard extends StatelessWidget {
  final Submission submission;
  final FAClient client;
  final bool sfwMode;
  final VoidCallback onTap;

  const SubmissionCard({
    super.key,
    required this.submission,
    required this.client,
    this.sfwMode = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
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
      ),
    );
  }

  Widget _buildImage() {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(11)),
          child: submission.imageUrl.isNotEmpty
              ? FAImage(
                  url: submission.imageUrl,
                  dynamicThumbnail: DynamicThumbnail(
                    Uri.parse(submission.imageUrl),
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
        if (submission.isNsfw && sfwMode)
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(11)),
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
            submission.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
          if (submission.author.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              submission.author,
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
