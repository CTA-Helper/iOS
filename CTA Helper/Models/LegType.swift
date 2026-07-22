import Foundation

/**
 An ARINC 424 path terminator: how a leg is flown, and what ends it.

 Most legs end at a named fix, and the fix list names them by their identifier. The ones that
 end at an altitude, an intercept or a manual termination code no fix to name, so
 ``LegInstruction`` reads the instruction off the leg type instead.
 */
enum LegType: String, Codable, Sendable {
  case arcToFix = "AF"
  case courseToAltitude = "CA"
  case courseToDME = "CD"
  case courseToFix = "CF"
  case courseToIntercept = "CI"
  case courseToRadial = "CR"
  case directToFix = "DF"
  case fixToAltitude = "FA"
  case trackFromFixForDistance = "FC"
  case trackFromFixToDME = "FD"
  case fromFixToManualTermination = "FM"
  case holdToAltitude = "HA"
  case holdToFix = "HF"
  case holdToManualTermination = "HM"
  case initialFix = "IF"
  case procedureTurn = "PI"
  case radiusToFix = "RF"
  case trackToFix = "TF"
  case headingToAltitude = "VA"
  case headingToDME = "VD"
  case headingToIntercept = "VI"
  case headingToManualTermination = "VM"
  case headingToRadial = "VR"
}
