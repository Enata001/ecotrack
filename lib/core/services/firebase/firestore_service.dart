import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService(this._db);

  CollectionReference<Map<String, dynamic>> get users => _db.collection('users');

  CollectionReference<Map<String, dynamic>> get collectors =>
      _db.collection('collectors');

  CollectionReference<Map<String, dynamic>> get wasteRequests =>
      _db.collection('wasteRequests');

  CollectionReference<Map<String, dynamic>> get receipts =>
      _db.collection('receipts');

  CollectionReference<Map<String, dynamic>> get scheduledPickups =>
      _db.collection('scheduledPickups');

  Future<void> runTransaction(
      Future<void> Function(Transaction transaction) action,
      ) {
    return _db.runTransaction(action);
  }
}