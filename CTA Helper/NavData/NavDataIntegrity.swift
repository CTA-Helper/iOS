import CryptoKit
import Foundation

/**
 Checks a downloaded cycle against the digest and byte counts its manifest publishes.

 The published cycle decides altitudes a pilot flies, so a download that does not match what the
 publisher signed is refused rather than imported: a truncated transfer or a mangled proxy cache
 would otherwise reach the store as a plausible-looking procedure.
 */
enum NavDataIntegrity {
  /// Check a compressed download against both the size and the digest the manifest published.
  static func verify(_ compressed: Data, against file: NavDataManifest.DataFile) throws {
    try verifySize(of: compressed, expecting: file.bytes)

    let digest = sha256(of: compressed)
    guard digest.caseInsensitiveCompare(file.sha256) == .orderedSame else {
      throw NavDataError.checksumMismatch(expected: file.sha256, actual: digest)
    }
  }

  /**
   Check a payload against the size the manifest published.

   Size is checked before the digest so a truncated download reports the length it actually
   got, which says far more than "the hash didn't match".
   */
  static func verifySize(of data: Data, expecting expectedBytes: UInt) throws {
    guard UInt(data.count) == expectedBytes else {
      throw NavDataError.sizeMismatch(
        expectedBytes: expectedBytes,
        actualBytes: UInt(data.count)
      )
    }
  }

  /// The lowercase hex SHA-256 of `data`, in the form the manifest publishes it.
  static func sha256(of data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
}
