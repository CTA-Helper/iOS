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
