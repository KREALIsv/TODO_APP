enum CloudVaultState {
  /// Sync plaintext or local-only; protection not enabled for the account.
  encryptionOff,

  /// JWT valid but this device has no DEK.
  authOnly,

  /// JWT + DEK; encrypted sync is operational.
  vaultReady,

  /// Device revoked; must pair again.
  revoked,
}
