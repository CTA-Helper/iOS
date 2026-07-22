import Foundation

/**
 Groups an approach's fixes into the sections the fix list renders: one per segment, in the
 order they are flown, each carrying the transitions that segment codes.

 A fix appears once per transition it is flown on, so the same identifier can occur several
 times within a segment. A section shows one transition at a time — the one the pilot selects —
 followed by the legs every transition converges onto, the segment's common route. The helper is
 generic over any element that exposes a segment, a transition name and a sequence, so it can be
 exercised without SwiftData.
 */
enum FixGrouping {
  /**
   Orders the sections for a set of fixes.

   Sections follow ``Segment``'s own order — initial, intermediate, final, missed. A segment no
   element falls in is omitted.

   - Parameters:
     - elements: the fixes to group.
     - segment: the segment an element falls in.
     - transition: the transition name of an element, or `nil` for the common route.
     - sequence: the element's order within its transition or the common route.
   - Returns: the ordered sections, each holding its segment's transitions and the legs they
     converge onto.
   */
  static func groups<Element>(
    _ elements: [Element],
    segment: (Element) -> Segment,
    transition: (Element) -> String?,
    sequence: (Element) -> UInt
  ) -> [Group<Element>] {
    Segment.allCases.compactMap { section in
      let legs = elements.filter { segment($0) == section }
      guard !legs.isEmpty else { return nil }

      return Group(
        segment: section,
        transitions: transitions(of: legs, transition: transition, sequence: sequence),
        commonElements: commonRoute(of: legs, transition: transition, sequence: sequence)
      )
    }
  }

  /**
   A segment's transitions by name, each holding the legs flown only on it.

   The order the legs arrive in cannot decide which transition a section offers first: they come
   from a SwiftData relationship, which has no defined order, so the same approach would open on
   a different route between launches. Sorting by name is stable, and reads the way a pilot
   scans a menu for the IAF they are cleared to.
   */
  private static func transitions<Element>(
    of elements: [Element],
    transition: (Element) -> String?,
    sequence: (Element) -> UInt
  ) -> [Transition<Element>] {
    Set(elements.compactMap(transition)).sorted().map { name in
      let legs = elements.filter { transition($0) == name }
      return Transition(name: name, elements: legs.sorted { sequence($0) < sequence($1) })
    }
  }

  /**
   The legs no transition claims — the ones every transition converges onto, in the order they
   are flown.
   */
  private static func commonRoute<Element>(
    of elements: [Element],
    transition: (Element) -> String?,
    sequence: (Element) -> UInt
  ) -> [Element] {
    elements.filter { transition($0) == nil }.sorted { sequence($0) < sequence($1) }
  }

  /**
   One rendered section: a segment, the transitions it codes, and the legs those transitions
   converge onto.
   */
  struct Group<Element>: Identifiable {
    /// The segment the section covers.
    let segment: Segment
    /// The transitions the segment codes, by name.
    let transitions: [Transition<Element>]
    /// The legs every transition converges onto — the segment's common route.
    let commonElements: [Element]

    var id: String { segment.rawValue }

    /**
     The legs flown via a transition, followed by the legs they converge onto.

     The common route is appended rather than merged by sequence: a converging leg routinely
     carries a lower sequence number than the transition legs that reach it, so ordering the two
     together by sequence would put the convergence point ahead of the route to it. A segment
     coding no transitions is read with `nil` and lists its common route alone.
     */
    func elements(via transition: String?) -> [Element] {
      let flown = transitions.first { $0.name == transition }?.elements ?? []
      return flown + commonElements
    }
  }

  /// One transition of a segment, with the legs flown only on it.
  struct Transition<Element>: Identifiable {
    /// The transition's name, as the procedure codes it.
    let name: String
    /// The legs flown only on this transition, in the order they are flown.
    let elements: [Element]

    var id: String { name }
  }
}
