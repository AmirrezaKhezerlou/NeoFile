import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/file_item.dart';
import '../providers/settings_provider.dart';
import '../services/file_service.dart';
import '../widgets/media/windows_audio_player.dart';
import '../widgets/media/windows_image_viewer.dart';
import '../widgets/media/windows_pdf_viewer.dart';
import '../widgets/media/windows_video_player.dart';

class MediaLauncher {
  static void openItem(
    BuildContext context,
    FileItem item, {
    List<FileItem>? siblings,
    bool forceExternal = false,
  }) {
    final settings = context.read<SettingsProvider>();

    if (forceExternal || !settings.useInternalMediaViewer) {
      FileService.openFile(item.path, useChooser: true);
      return;
    }

    if (item.isImage) {
      WindowsImageViewer.show(context, item, siblings);
    } else if (item.isVideo) {
      WindowsVideoPlayer.show(context, item);
    } else if (item.isAudio) {
      WindowsAudioPlayer.show(context, item, siblings);
    } else if (item.isPdf) {
      WindowsPdfViewer.show(context, item);
    } else {
      FileService.openFile(item.path, useChooser: false);
    }
  }
}
