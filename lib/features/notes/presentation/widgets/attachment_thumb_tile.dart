import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import '../../../../global/themes/tokens.dart';

/// Shared thumbnail used by the editor strip and “Ver más” grid.
class AttachmentThumbTile extends StatelessWidget {
  const AttachmentThumbTile({
    super.key,
    required this.bytes,
    required this.isCover,
    required this.onTap,
    this.onLongPress,
    this.size = 64,
  });

  final Uint8List? bytes;
  final bool isCover;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double size;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: ThemeTokens.borderRadius,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: ThemeTokens.borderRadius,
            child: Container(
              width: size,
              height: size,
              color: AppColors.neutral20,
              child: bytes == null
                  ? const Icon(Icons.broken_image_outlined)
                  : Image.memory(bytes!, fit: BoxFit.cover),
            ),
          ),
          if (isCover)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star, size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
