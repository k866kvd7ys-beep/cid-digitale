class ClaimDraftCreationGuard {
  Future<String>? _pendingCreation;

  Future<String> resolve({
    required String? existingClaimId,
    required bool Function(String claimId) isPersistedClaimId,
    required Future<String> Function() createClaim,
    required void Function(String claimId) onClaimCreated,
  }) {
    final normalizedExistingId = existingClaimId?.trim() ?? '';
    if (isPersistedClaimId(normalizedExistingId)) {
      return Future.value(normalizedExistingId);
    }

    final pendingCreation = _pendingCreation;
    if (pendingCreation != null) {
      return pendingCreation;
    }

    late final Future<String> creation;
    creation = Future<String>.sync(createClaim).then((claimId) {
      final normalizedClaimId = claimId.trim();
      if (!isPersistedClaimId(normalizedClaimId)) {
        throw StateError('claim_draft_creation_returned_invalid_id');
      }
      onClaimCreated(normalizedClaimId);
      return normalizedClaimId;
    }).whenComplete(() {
      if (identical(_pendingCreation, creation)) {
        _pendingCreation = null;
      }
    });
    _pendingCreation = creation;
    return creation;
  }

  Future<String?> waitForPendingCreation() async {
    final pendingCreation = _pendingCreation;
    if (pendingCreation == null) return null;
    return pendingCreation;
  }
}
