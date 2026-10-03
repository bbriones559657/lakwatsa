import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

/// The fake's dummy transactions start writes without awaiting their futures.
/// Drain that event turn so sequential test operations observe committed writes.
/// This does NOT emulate transaction conflicts/rollback; test those on Firebase.
class SettledFirestore extends FakeFirebaseFirestore {
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final result = await super.runTransaction(
      transactionHandler,
      timeout: timeout,
      maxAttempts: maxAttempts,
    );
    await Future<void>.delayed(Duration.zero);
    return result;
  }
}
