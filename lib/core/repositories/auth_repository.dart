import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' show FirebaseFunctionsException;
import 'package:firebase_auth/firebase_auth.dart';

import '../exceptions/result.dart';
import '../models/app_user.dart';
import '../models/saved_address.dart';
import '../services/firebase/cloud_functions_service.dart';
import '../services/firebase/fcm_service.dart';
import '../services/firebase/firebase_auth_service.dart';
import '../services/firebase/firestore_service.dart';
import '../services/firebase/storage_service.dart';
import '../utils/enums.dart';

class AuthRepository {
  final FirebaseAuthService _authService;
  final FirestoreService _firestore;
  final CloudFunctionsService _functions;
  final StorageService _storage;
  final FcmService _fcm;

  AuthRepository(
      this._authService,
      this._firestore,
      this._functions,
      this._storage,
      this._fcm,
      );

  Stream<User?> get authStateChanges => _authService.authStateChanges;

  Future<Result<AppUser>> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    VehicleType? vehicleType,
  }) async {
    try {
      final credential = await _authService.signUp(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;

      final appUser = AppUser(
        uid: uid,
        name: name,
        email: email,
        role: role,
        vehicleType: vehicleType,
      );

      await _firestore.users.doc(uid).set(appUser.toUserMap());

      if (role == UserRole.collector) {
        await _firestore.collectors.doc(uid).set(appUser.toCollectorMap());
      }

      return Success(appUser);
    } on FirebaseAuthException catch (e) {
      return Failure(AppException(message: _authMessage(e), code: e.code));
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  Future<Result<AppUser>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _authService.signIn(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;
      final appUser = await fetchAppUser(uid);
      if (appUser == null) {
        return Failure(AppException(message: 'User profile not found.'));
      }
      return Success(appUser);
    } on FirebaseAuthException catch (e) {
      return Failure(AppException(message: _authMessage(e), code: e.code));
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  Future<AppUser?> fetchAppUser(String uid) async {
    final userDoc = await _firestore.users.doc(uid).get();
    if (!userDoc.exists) return null;

    final data = userDoc.data()!;
    if (UserRole.fromString(data['role'] ?? 'user') == UserRole.collector) {
      final collectorDoc = await _firestore.collectors.doc(uid).get();
      return AppUser.fromMap(uid, {...data, ...?collectorDoc.data()});
    }
    return AppUser.fromMap(uid, data);
  }

  Future<void> registerFcmToken({
    required String uid,
    required UserRole role,
    required String token,
  }) async {
    await _firestore.users.doc(uid).set({'fcmToken': token}, SetOptions(merge: true));
    if (role == UserRole.collector) {
      await _firestore.collectors
          .doc(uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    }
  }


  Future<void> signOut() async {
    final firebaseUser = _authService.currentUser;
    if (firebaseUser != null) {
      final appUser = await fetchAppUser(firebaseUser.uid);
      if (appUser != null) {
        await _clearFcmToken(uid: appUser.uid, role: appUser.role);
      }
    }
    await _fcm.deleteToken();
    await _authService.signOut();
  }

  Future<void> _clearFcmToken({required String uid, required UserRole role}) async {
    try {
      await _firestore.users.doc(uid).update({'fcmToken': null});
      if (role == UserRole.collector) {
        await _firestore.collectors.doc(uid).update({'fcmToken': null});
      }
    } catch (_) {
      // Best-effort — don't block sign-out over this.
    }
  }

  Future<Result<void>> resetPassword(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      return const Success(null);
    } on FirebaseAuthException catch (e) {
      return Failure(AppException(message: _authMessage(e), code: e.code));
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  Future<Result<void>> updateProfile({
    required String uid,
    String? name,
    String? phone,
    String? photoUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;
      if (updates.isEmpty) return const Success(null);

      await _firestore.users.doc(uid).update(updates);
      return const Success(null);
    } catch (e) {
      return Failure(AppException(message: 'Could not update profile.'));
    }
  }

  Future<Result<String>> uploadProfilePhoto({
    required String uid,
    required File file,
  }) async {
    try {
      final url = await _storage.uploadProfilePhoto(uid: uid, file: file);
      await _firestore.users.doc(uid).update({'photoUrl': url});
      return Success(url);
    } catch (e) {
      return Failure(AppException(message: 'Could not upload photo.'));
    }
  }


  Future<Result<void>> setNotificationsEnabled({
    required String uid,
    required UserRole role,
    required bool enabled,
    String? fcmToken,
  }) async {
    try {
      final updates = <String, dynamic>{
        'notificationsEnabled': enabled,
        'fcmToken': enabled ? fcmToken : null,
      };
      await _firestore.users.doc(uid).update(updates);
      if (role == UserRole.collector) {
        await _firestore.collectors.doc(uid).update(updates);
      }
      return const Success(null);
    } catch (e) {
      return Failure(AppException(message: 'Could not update notification settings.'));
    }
  }


  Future<Result<void>> addSavedAddress({
    required String uid,
    required SavedAddress address,
  }) async {
    try {
      await _firestore.users.doc(uid).update({
        'savedAddresses': FieldValue.arrayUnion([address.toJson()]),
      });
      return const Success(null);
    } catch (e) {
      return Failure(AppException(message: 'Could not save address.'));
    }
  }

  Future<Result<void>> removeSavedAddress({
    required String uid,
    required String rawEntry,
  }) async {
    try {
      await _firestore.users.doc(uid).update({
        'savedAddresses': FieldValue.arrayRemove([rawEntry]),
      });
      return const Success(null);
    } catch (e) {
      return Failure(AppException(message: 'Could not remove address.'));
    }
  }

  Future<Result<void>> deleteAccount() async {
    try {
      await _functions.deleteAccount();
      return const Success(null);
    } catch (e) {
      return Failure(AppException(message: _deleteAccountErrorMessage(e)));
    }
  }

  String _deleteAccountErrorMessage(Object e) {
    if (e is FirebaseFunctionsException) {
      switch (e.code) {
        case 'failed-precondition':
          return e.message ??
              'You have an active pickup request. Cancel or complete it before deleting your account.';
        case 'unauthenticated':
          return 'Please sign in again.';
        default:
          return e.message ?? 'Could not delete your account (${e.code}).';
      }
    }
    return 'Could not delete your account. Please try again.';
  }

  String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'weak-password':
        return 'Password is too weak.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }
}