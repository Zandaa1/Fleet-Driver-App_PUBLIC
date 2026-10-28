import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'permission_guard.dart';

class ImagePickerHelper {
  static Future<XFile?> showImageSourceDialog(BuildContext context) async {
    Future<void> pickAndReturn(
      BuildContext sheetContext,
      ImageSource source,
    ) async {
      final ImagePicker picker = ImagePicker();

      try {
        if (source == ImageSource.camera) {
          final granted = await PermissionGuard.ensureCameraPermission(
            sheetContext,
          );
          if (!granted) return;
        } else {
          final granted = await PermissionGuard.ensurePhotoLibraryPermission(
            sheetContext,
          );
          if (!granted) return;
        }

        final XFile? image = await picker.pickImage(
          source: source,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 70, // Balanced quality vs size
        );

        if (sheetContext.mounted) {
          Navigator.pop(sheetContext, image);
        }
      } catch (e) {
        if (sheetContext.mounted) {
          ScaffoldMessenger.of(
            sheetContext,
          ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
          Navigator.pop(sheetContext);
        }
      }
    }

    return await showModalBottomSheet<XFile?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Choose Photo Source',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.camera_alt,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: const Text('Take Photo'),
                  subtitle: const Text('Use camera to take a new photo'),
                  onTap: () => pickAndReturn(context, ImageSource.camera),
                ),
                const Divider(),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.photo_library,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  title: const Text('Choose from Gallery'),
                  subtitle: const Text('Select an existing photo'),
                  onTap: () => pickAndReturn(context, ImageSource.gallery),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }
}
