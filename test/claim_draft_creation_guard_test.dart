import 'dart:async';

import 'package:cid_digitale/services/claim_draft_creation_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const persistedId = '11111111-1111-4111-8111-111111111111';
  bool isPersisted(String value) => value == persistedId;

  test('concurrent draft requests share one insert', () async {
    final guard = ClaimDraftCreationGuard();
    final gate = Completer<String>();
    var insertCalls = 0;
    String? storedId;

    Future<String> create() {
      insertCalls++;
      return gate.future;
    }

    final first = guard.resolve(
      existingClaimId: 'local-id',
      isPersistedClaimId: isPersisted,
      createClaim: create,
      onClaimCreated: (claimId) => storedId = claimId,
    );
    final second = guard.resolve(
      existingClaimId: 'local-id',
      isPersistedClaimId: isPersisted,
      createClaim: create,
      onClaimCreated: (claimId) => storedId = claimId,
    );

    expect(insertCalls, 1);
    expect(identical(first, second), isTrue);

    gate.complete(persistedId);
    expect(await Future.wait([first, second]), [persistedId, persistedId]);
    expect(storedId, persistedId);
  });

  test('an existing persisted claim bypasses insert', () async {
    final guard = ClaimDraftCreationGuard();
    var insertCalls = 0;

    final resolved = await guard.resolve(
      existingClaimId: persistedId,
      isPersistedClaimId: isPersisted,
      createClaim: () async {
        insertCalls++;
        return persistedId;
      },
      onClaimCreated: (_) {},
    );

    expect(resolved, persistedId);
    expect(insertCalls, 0);
  });

  test('submit can await the in-flight draft creation', () async {
    final guard = ClaimDraftCreationGuard();
    final gate = Completer<String>();

    final creation = guard.resolve(
      existingClaimId: 'local-id',
      isPersistedClaimId: isPersisted,
      createClaim: () => gate.future,
      onClaimCreated: (_) {},
    );
    final pendingForSubmit = guard.waitForPendingCreation();

    gate.complete(persistedId);
    expect(await pendingForSubmit, persistedId);
    expect(await creation, persistedId);
    expect(await guard.waitForPendingCreation(), isNull);
  });

  test('a failed insert releases the guard for a retry', () async {
    final guard = ClaimDraftCreationGuard();
    var insertCalls = 0;

    Future<String> create() async {
      insertCalls++;
      if (insertCalls == 1) throw StateError('network');
      return persistedId;
    }

    await expectLater(
      guard.resolve(
        existingClaimId: 'local-id',
        isPersistedClaimId: isPersisted,
        createClaim: create,
        onClaimCreated: (_) {},
      ),
      throwsStateError,
    );

    final resolved = await guard.resolve(
      existingClaimId: 'local-id',
      isPersistedClaimId: isPersisted,
      createClaim: create,
      onClaimCreated: (_) {},
    );

    expect(resolved, persistedId);
    expect(insertCalls, 2);
  });
}
