import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> isStoragePermissionGranted() async {
    if (!Platform.isAndroid) return true;

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 30) {
        return await Permission.manageExternalStorage.isGranted;
      } else {
        return await Permission.storage.isGranted;
      }
    } catch (_) {
      // Fallback
      return await Permission.manageExternalStorage.isGranted ||
          await Permission.storage.isGranted;
    }
  }

  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 30) {
        final status = await Permission.manageExternalStorage.request();
        return status.isGranted;
      } else {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } catch (_) {
      final status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    }
  }

  static Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> isInstallPackagesPermissionGranted() async {
    if (!Platform.isAndroid) return true;
    try {
      return await Permission.requestInstallPackages.isGranted;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestInstallPackagesPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final status = await Permission.requestInstallPackages.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestAllInitialPermissions() async {
    final storageOk = await requestStoragePermission();
    await requestNotificationPermission();
    return storageOk;
  }

  static Future<void> openSystemSettings() async {
    await openAppSettings();
  }
}
