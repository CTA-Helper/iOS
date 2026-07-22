import Foundation

/**
 The altitude each correction method enters the cold temperature calculation with.

 The four individual segments follow AIP ENR 1.8 5.f.2.1; ``allSegments`` is the single
 reference the All Segments Method uses for the whole approach from the IAF to the FAF
 (ENR 1.8 5.f.1). A segment whose reference the coded procedure did not publish carries a
 ``ReferenceAltitude`` case saying why — ``ReferenceAltitude/unavailable`` or
 ``ReferenceAltitude/pilotEntered``.
 */
struct ReferenceAltitudes: Codable, Hashable, Sendable {
  var initial: ReferenceAltitude
  var intermediate: ReferenceAltitude
  var final: ReferenceAltitude
  var missed: ReferenceAltitude
  var allSegments: ReferenceAltitude

  /**
   The reference a given segment uses under the given method.

   Both methods take the final reference from the pilot-entered DA/MDA and the missed
   reference from the holding altitude. They differ only on the initial and intermediate
   segments: the All Segments Method corrects both from the FAF, while the Individual
   Segments Method uses each segment's own reference.
   */
  func reference(for segment: Segment, method: CorrectionMethod) -> ReferenceAltitude {
    switch (segment, method) {
      case (.initial, .allSegments), (.intermediate, .allSegments): allSegments
      case (.initial, .individualSegments): initial
      case (.intermediate, .individualSegments): intermediate
      case (.final, _): final
      case (.missed, _): missed
    }
  }
}
