import Foundation

/**
 The `@AppStorage` keys for the app's persisted settings.

 They live in one place so the fixes screen (which reads the correction settings) and the
 settings screen (which writes them) always agree. Each setting's default is given at every
 `@AppStorage` use site:

 ```swift
 @AppStorage(SettingsKey.correctionRounding)
 private var rounding = CorrectionRounding.nearestHundred

 @AppStorage(SettingsKey.extrapolateAboveTable)
 private var extrapolateAboveTable = false

 @AppStorage(SettingsKey.correctionMethod)
 private var method = CorrectionMethod.allSegments
 ```
 */
enum SettingsKey {
  /// How corrections are rounded (``CorrectionRounding``); default `.nearestHundred`.
  static let correctionRounding = "correctionRounding"
  /**
   Whether to evaluate the formula above the table's 5,000 ft ceiling (`Bool`); default
   `false` (cap at 5,000 ft, matching the FAA example).
   */
  static let extrapolateAboveTable = "extrapolateAboveTable"
  /// The last-used correction method (``CorrectionMethod``); default `.allSegments`.
  static let correctionMethod = "correctionMethod"
}

extension SettingsKey {
  /**
   Which generation of the nav data store the app reads (`Int`); default
   ``NavDataStore/emptyGeneration``.

   Written only by ``NavDataStoreInstaller``, once a new generation has been found to hold a
   dataset, so this one number is what makes switching datasets atomic.
   */
  static let activeNavDataGeneration = "activeNavDataGeneration"
  /**
   The `NavDataSchema.version` the active generation was installed under (`Int`); default the
   current version.

   A build that raises the version finds an older number here and asks for the data again,
   because the rows already on disk mean something different under the new one.
   */
  static let navDataSchemaVersion = "navDataSchemaVersion"
  /**
   Whether a background update may use a network iOS treats as metered (`Bool`); default `false`.

   An update the pilot starts themselves uses any network; one the system starts while the device
   charges waits for an unmetered one unless this allows otherwise.
   */
  static let allowsBackgroundMeteredDownloads = "allowsBackgroundMeteredDownloads"
}
