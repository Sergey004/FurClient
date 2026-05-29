import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/adaptive/adaptive.dart';
import '../utils/fa_image_loader.dart';

class SubmissionCard extends StatelessWidget {
  final FASubmissionPreview submission;
  final OnlineFASession session;
  final bool sfwMode;
  final VoidCallback onTap;

  const SubmissionCard({
    super.key,
    required this.submission,
    required this.session,
    this.sfwMode = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
    );
  }

  Widget _buildImage() {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(11)),
          child: FAImage(
              url: submission.thumbnailUrl.toString(),
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
