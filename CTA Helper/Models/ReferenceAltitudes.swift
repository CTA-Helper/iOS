import Foundation
import NavDataSchema

extension ReferenceAltitudes {
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
