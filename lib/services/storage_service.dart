import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadDeliveryPhoto(String orderId, File imageFile) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_${path.basename(imageFile.path)}';
      final ref = _storage.ref().child('delivery_photos/$orderId/$fileName');

      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload photo: $e');
    }
  }

  Future<String> uploadDeliveryPhotoWithProgress(
    String orderId,
    File imageFile,
    Function(double) onProgress,
  ) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_${path.basename(imageFile.path)}';
      final ref = _storage.ref().child('delivery_photos/$orderId/$fileName');

      final uploadTask = ref.putFile(imageFile);

      uploadTask.snapshotEvents.listen((taskSnapshot) {
        final progress =
            taskSnapshot.bytesTransferred / taskSnapshot.totalBytes;
        onProgress(progress);
      });

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload photo: $e');
    }
  }

  Future<void> deleteDeliveryPhoto(String photoUrl) async {
    try {
      final ref = _storage.refFromURL(photoUrl);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete photo: $e');
    }
  }

  Future<File> saveImageToLocal(File imageFile) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'image_$timestamp.jpg';
      final localFile = File('${appDir.path}/$fileName');

      await imageFile.copy(localFile.path);
      return localFile;
    } catch (e) {
      throw Exception('Failed to save image: $e');
    }
  }
}
