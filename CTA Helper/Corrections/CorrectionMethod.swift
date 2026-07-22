import Foundation

/// The two methods AIP ENR 1.8 5.f offers for applying cold temperature corrections.
enum CorrectionMethod: String, CaseIterable, Identifiable, Sendable {
  /**
   Correct every altitude from the IAF down to the missed approach holding altitude, using
   the FAF altitude for everything above the final segment (ENR 1.8 5.f.1).
   */
  case allSegments
  /**
   Correct only the segments the CTA list marks, each from its own reference altitude
   (ENR 1.8 5.f.2).
   */
  case individualSegments

  var id: Self { self }
}
