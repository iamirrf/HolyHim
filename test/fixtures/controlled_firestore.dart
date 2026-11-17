import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore stand-ins whose snapshots and write receipts a test controls.
class ControlledFirestore implements FirebaseFirestore {
  final documents = <String, ControlledDocument>{};
  @override
  ControlledDocument doc(String path) =>
      documents.putIfAbsent(path, () => ControlledDocument());
  Future<void> close() async {
    for (final doc in documents.values) {
      await doc.snapshotsController.close();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Test-only SDK stand-ins: these public types have private constructors.
// ignore: subtype_of_sealed_class
class ControlledDocument implements DocumentReference<Map<String, dynamic>> {
  final snapshotsController =
      StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast(
          sync: true);
  final writes = <({
    Map<String, dynamic> data,
    SetOptions? options,
    Completer<void> receipt
  })>[];
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots(
          {bool includeMetadataChanges = false,
          ListenSource source = ListenSource.defaultSource}) =>
      snapshotsController.stream;
  void emit(Map<String, dynamic>? data,
          {bool cached = true, bool pending = false}) =>
      snapshotsController
          .add(ControlledSnapshot(data, cached: cached, pending: pending));
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) {
    final receipt = Completer<void>();
    writes.add((data: data, options: options, receipt: receipt));
    return receipt.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class ControlledSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic>? value;
  final bool cached, pending;
  ControlledSnapshot(this.value, {this.cached = true, this.pending = false});
  @override
  Map<String, dynamic>? data() => value;
  @override
  SnapshotMetadata get metadata =>
      ControlledMetadata(cached: cached, pending: pending);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ControlledMetadata implements SnapshotMetadata {
  final bool cached, pending;
  ControlledMetadata({required this.cached, required this.pending});
  @override
  bool get isFromCache => cached;
  @override
  bool get hasPendingWrites => pending;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
