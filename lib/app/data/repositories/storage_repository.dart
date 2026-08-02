import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/config/app_config.dart';

/// Repository interface for Firebase Storage operations.
abstract class IStorageRepository {
  Future<String> uploadBytes({
    required Uint8List bytes,
    required String path,
    required String contentType,
  });
}

/// Firebase Storage implementation of [IStorageRepository].
class StorageRepository implements IStorageRepository {
  final FirebaseStorage _storage;

  StorageRepository({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  @override
  Future<String> uploadBytes({
    required Uint8List bytes,
    required String path,
    required String contentType,
  }) async {
    if (AppConfig.isMock) {
      return 'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?w=800';
    }

    final ref = _storage.ref().child(path);
    final metadata = SettableMetadata(
      contentType: contentType,
      cacheControl: 'public, max-age=31536000',
    );

    final uploadTask = ref.putData(bytes, metadata);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }
}
