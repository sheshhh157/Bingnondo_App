import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Requests camera access only when the user chooses to take a photo.
Future<bool> requestCameraAccess(BuildContext context) async {
  final status = await Permission.camera.request();
  if (status.isGranted) return true;
  if (!context.mounted) return false;

  final openSettings = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Camera access is off'),
      content: const Text(
        'Camera access was denied. Allow Bingnondo to use the camera in app settings to take a photo.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Not now'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Open Settings'),
        ),
      ],
    ),
  );
  if (openSettings == true) await openAppSettings();
  return false;
}
