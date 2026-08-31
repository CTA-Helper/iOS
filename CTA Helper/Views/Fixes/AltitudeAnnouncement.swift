import Foundation

/**
 How ``AltitudeView``'s rendering of a ``CorrectedAltitude`` reads aloud.

 ``FixRow`` is one accessibility element, so nothing drawn inside it speaks for itself: the
 digits, the stroke through the superseded value and the restriction bars all reach VoiceOver
 through these strings. Each one names what its number is, because a row that reads
 "10,000, 10,700" leaves the pilot to work out which altitude the procedure published and which
 one they fly.
 */
extension CorrectedAltitude {
  /// The altitude the pilot flies, and how the fix constrains them at it.
  var announcement: String {
    switch published {
      case .unpublished:
        String(localized: "No published altitude")
      case let .single(publishedFt, restriction, _):
        String(
          localized: "\(operative(or: .feet(publishedFt))), \(restriction.barDescription)",
          comment: "Fix row read aloud: the altitude flown, then how the fix is crossed"
        )
      case let .block(ceilingFt, floorFt):
        String(
          localized: "\(operative(or: .feet(floorFt))) to \(spoken(.feet(ceilingFt)))",
          comment: "Fix row read aloud: a block’s floor, then its ceiling"
        )
    }
  }

  /**
   The published altitude a correction superseded, or `nil` where none did.

   A block names which of its two published altitudes this is. Only its floor is corrected, and
   a bare number beside a spoken range would be as likely to read as the ceiling that never
   moved.
   */
  var supersededAnnouncement: String? {
    guard corrected != nil else { return nil }
    return switch published {
      case .unpublished: nil
      case let .single(publishedFt, _, _): spoken(.feet(publishedFt))
      case let .block(_, floorFt):
        String(
          localized: "floor \(spoken(.feet(floorFt)))",
          comment: "The published lower bound of a block altitude, read aloud"
        )
    }
  }

  /// The glidepath or VNAV altitude the fix codes beneath its primary one, or `nil`.
  var glidepathAnnouncement: String? {
    guard case let .single(_, _, glidepathFt) = published, let glidepathFt else { return nil }
    return spoken(.feet(glidepathFt))
  }

  /// What ENR 1.8 adds to the altitude it corrects, or `nil` where it corrects nothing.
  var correctionAnnouncement: String? {
    guard case let .add(addend) = correction else { return nil }
    return addend.formatted(.spokenCorrection)
  }

  /// The corrected altitude where one applies, and the published one where none does.
  private func operative(or publishedAltitude: Measurement<UnitLength>) -> String {
    spoken(corrected ?? publishedAltitude)
  }

  private func spoken(_ altitude: Measurement<UnitLength>) -> String {
    altitude.formatted(.spokenAltitude)
  }
}

private extension AltitudeRestriction {
  /**
   What the restriction bars say, in the terms the FAA chart legend names them by.

   ``RestrictionBar`` draws the bars as rules, which carry no accessibility element of their
   own: without this, VoiceOver would read the digits and nothing about how the fix is crossed.
   Reading the wording off the bars rather than off the case keeps the two in step — a
   description that draws no bar, a glidepath altitude among them, is a recommended altitude and
   is announced as one.
   */
  var barDescription: String {
    switch (hasBarAbove, hasBarBelow) {
      case (true, true): String(localized: "mandatory altitude")
      case (true, false): String(localized: "maximum altitude")
      case (false, true): String(localized: "minimum altitude")
      case (false, false): String(localized: "recommended altitude")
    }
  }
}
