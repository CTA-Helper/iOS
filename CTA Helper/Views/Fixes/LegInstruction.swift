import Foundation

/**
 The instruction a leg stands for, set above the fix name wherever the leg is flown to
 something other than the fix itself — a climb to an altitude, a hold, an intercept.

 A leg that simply tracks to a named fix carries no instruction: the fix's name is the whole
 of it, and an overline saying so would only repeat the row.

 The FAA release codes no course on a fix, so an intercept reads generically rather than as
 the "Course 135 to" a plate prints.
 */
enum LegInstruction {
  /**
   The instruction for a leg of the given type, or `nil` for a leg that only tracks to its fix
   and for a path terminator the app does not recognize.
   */
  static func instruction(for legType: LegType?) -> String? {
    switch legType {
      case .courseToAltitude, .headingToAltitude, .fixToAltitude:
        String(localized: "Climb to")
      case .holdToAltitude, .holdToFix, .holdToManualTermination:
        String(localized: "Hold at")
      case .procedureTurn:
        String(localized: "Procedure turn at")
      case .courseToIntercept, .headingToIntercept, .courseToRadial, .headingToRadial:
        String(localized: "Turn to intercept")
      case .courseToDME, .headingToDME, .trackFromFixToDME, .trackFromFixForDistance:
        String(localized: "Proceed to")
      case .arcToFix, .radiusToFix:
        String(localized: "Arc to")
      case .fromFixToManualTermination, .headingToManualTermination:
        String(localized: "Proceed from")
      case .initialFix, .trackToFix, .courseToFix, .directToFix, nil:
        nil
    }
  }
}
