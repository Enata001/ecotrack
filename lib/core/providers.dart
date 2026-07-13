import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories/auth_repository.dart';
import 'repositories/collector_repository.dart';
import 'repositories/request_repository.dart';
import 'services/firebase/cloud_functions_service.dart';
import 'services/firebase/fcm_service.dart';
import 'services/firebase/firebase_auth_service.dart';
import 'services/firebase/firestore_service.dart';
import 'services/firebase/storage_service.dart';
import 'services/local_storage_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider = Provider<FirebaseFirestore>(
      (ref) => FirebaseFirestore.instance,
);

final firebaseFunctionsProvider = Provider<FirebaseFunctions>(
      (ref) => FirebaseFunctions.instance,
);

final authServiceProvider = Provider<FirebaseAuthService>(
      (ref) => FirebaseAuthService(ref.watch(firebaseAuthProvider)),
);

final firestoreServiceProvider = Provider<FirestoreService>(
      (ref) => FirestoreService(ref.watch(firestoreProvider)),
);

final cloudFunctionsServiceProvider = Provider<CloudFunctionsService>(
      (ref) => CloudFunctionsService(ref.watch(firebaseFunctionsProvider)),
);

final firebaseStorageProvider = Provider<FirebaseStorage>(
      (ref) => FirebaseStorage.instance,
);

final storageServiceProvider = Provider<StorageService>(
      (ref) => StorageService(ref.watch(firebaseStorageProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
      (ref) => AuthRepository(
    ref.watch(authServiceProvider),
    ref.watch(firestoreServiceProvider),
    ref.watch(cloudFunctionsServiceProvider),
    ref.watch(storageServiceProvider),
    ref.watch(fcmServiceProvider),
  ),
);

final requestRepositoryProvider = Provider<RequestRepository>(
      (ref) => RequestRepository(
    ref.watch(firestoreServiceProvider),
    ref.watch(cloudFunctionsServiceProvider),
    ref.watch(storageServiceProvider),
  ),
);

final collectorRepositoryProvider = Provider<CollectorRepository>(
      (ref) => CollectorRepository(ref.watch(firestoreServiceProvider)),
);

final firebaseMessagingProvider = Provider<FirebaseMessaging>(
      (ref) => FirebaseMessaging.instance,
);

final fcmServiceProvider = Provider<FcmService>(
      (ref) => FcmService(ref.watch(firebaseMessagingProvider)),
);

final localStorageServiceProvider = Provider<LocalStorageService>(
      (ref) => throw UnimplementedError('localStorageServiceProvider not overridden'),
);

final authStateChangesProvider = StreamProvider<User?>(
      (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);