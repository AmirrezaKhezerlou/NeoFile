import 'dart:io';
import 'package:flutter/material.dart';
import '../models/file_item.dart';

class FluentFileIcon extends StatelessWidget {
  final FileItem item;
  final double size;

  const FluentFileIcon({
    super.key,
    required this.item,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    if (item.isDirectory) {
      return _buildFolderIcon();
    }
    if (item.isImage) {
      return _buildImageThumbnail();
    }
    return _buildFileBadge();
  }

  Widget _buildImageThumbnail() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black.withOpacity(0.08), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.file(
        File(item.path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 2.5).toInt().clamp(48, 256),
        cacheHeight: (size * 2.5).toInt().clamp(48, 256),
        errorBuilder: (context, error, stackTrace) => _buildFileBadge(),
      ),
    );
  }

  Widget _buildFolderIcon() {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _FolderPainter(),
      ),
    );
  }

  Widget _buildFileBadge() {
    Color badgeColor = const Color(0xFF5C5C5C);
    String label = item.extension.toUpperCase();
    IconData iconData = Icons.insert_drive_file_outlined;

    if (item.isPdf) {
      badgeColor = const Color(0xFFD83B01);
      label = 'PDF';
      iconData = Icons.picture_as_pdf;
    } else if (item.isWord) {
      badgeColor = const Color(0xFF0078D4);
      label = 'W';
      iconData = Icons.description;
    } else if (item.isExcel) {
      badgeColor = const Color(0xFF107C41);
      label = 'X';
      iconData = Icons.table_chart;
    } else if (item.isPpt) {
      badgeColor = const Color(0xFFD83B01);
      label = 'P';
      iconData = Icons.slideshow;
    } else if (item.isImage) {
      badgeColor = const Color(0xFF008378);
      label = item.extension.toUpperCase();
      iconData = Icons.image;
    } else if (item.isVideo) {
      badgeColor = const Color(0xFFE3008C);
      label = item.extension.toUpperCase();
      iconData = Icons.movie;
    } else if (item.isAudio) {
      badgeColor = const Color(0xFFB146C2);
      label = item.extension.toUpperCase();
      iconData = Icons.audio_file;
    } else if (item.isArchive) {
      badgeColor = const Color(0xFF744DA9);
      label = 'ZIP';
      iconData = Icons.folder_zip;
    } else if (item.isApk) {
      badgeColor = const Color(0xFF2E7D32);
      label = 'APK';
      iconData = Icons.android;
    } else if (item.isCode) {
      badgeColor = const Color(0xFF2B88D8);
      label = item.extension.toUpperCase();
      iconData = Icons.code;
    }

    if (label.length > 4) {
      label = label.substring(0, 3);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: badgeColor.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            iconData,
            size: size * 0.58,
            color: badgeColor,
          ),
          if (label.isNotEmpty && size >= 28)
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0.5),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: (size * 0.22).clamp(7.0, 9.5),
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FolderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Windows 11 Fluent Folder style:
    // Back tab
    final backPaint = Paint()
      ..color = const Color(0xFFD98200)
      ..style = PaintingStyle.fill;

    final backPath = Path()
      ..moveTo(w * 0.08, h * 0.24)
      ..lineTo(w * 0.42, h * 0.24)
      ..lineTo(w * 0.52, h * 0.35)
      ..lineTo(w * 0.92, h * 0.35)
      ..quadraticBezierTo(w * 0.96, h * 0.35, w * 0.96, h * 0.42)
      ..lineTo(w * 0.96, h * 0.82)
      ..quadraticBezierTo(w * 0.96, h * 0.88, w * 0.90, h * 0.88)
      ..lineTo(w * 0.08, h * 0.88)
      ..quadraticBezierTo(w * 0.04, h * 0.88, w * 0.04, h * 0.82)
      ..lineTo(w * 0.04, h * 0.30)
      ..quadraticBezierTo(w * 0.04, h * 0.24, w * 0.08, h * 0.24)
      ..close();
    canvas.drawPath(backPath, backPaint);

    // Front flap
    final frontPaint = Paint()
      ..color = const Color(0xFFFFB900)
      ..style = PaintingStyle.fill;

    final frontRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.04, h * 0.36, w * 0.92, h * 0.52),
      Radius.circular(w * 0.08),
    );
    canvas.drawRRect(frontRRect, frontPaint);

    // Front highlight
    final highlightPaint = Paint()
      ..color = const Color(0xFFFFC83B)
      ..style = PaintingStyle.fill;

    final highlightRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.04, h * 0.44, w * 0.92, h * 0.44),
      Radius.circular(w * 0.07),
    );
    canvas.drawRRect(highlightRRect, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
