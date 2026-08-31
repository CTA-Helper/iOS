import SwiftUI

extension View {
  /**
   Draws the over and under bars an ``AltitudeRestriction`` places around the altitude it
   bounds.

   The bars are the chart's own notation, and they carry the constraint itself rather than
   decorate it: `4,000` between two bars is an altitude to cross at, the same digits over a
   single bar are a floor to stay above, and under one alone they are a ceiling. An altitude
   shown without them says only how high, never whether the aircraft may be higher.

   They are overlays rather than rules stacked around the text so that each spans exactly the
   digits it bounds, and so a line of altitudes keeps one baseline whether or not any of them
   is barred.

   Each bar states its own colour rather than inheriting one. An unstyled shape picks up
   whatever fill the surrounding container hands down, which left the bars a shade lighter than
   the digits they bound — reading as a hairline drawn under the number instead of as part of
   the same mark.
   */
  func restrictionBars(_ restriction: AltitudeRestriction) -> some View {
    padding(.vertical, 3)
      .overlay(alignment: .top) {
        if restriction.hasBarAbove { RestrictionBar() }
      }
      .overlay(alignment: .bottom) {
        if restriction.hasBarBelow { RestrictionBar() }
      }
  }
}

/// A rule standing in for the over/under restriction bar SwiftUI has no primitive for.
private struct RestrictionBar: View {
  /// Heavy enough to read as the chart's own bar at a glance, rather than as a hairline rule.
  private static let thickness = 2.5

  var body: some View {
    Rectangle()
      .frame(height: Self.thickness)
      .padding(.horizontal, -3)
      // The label colour itself, rather than `.primary`, `.foreground` or `Color.primary`.
      // Over Liquid Glass every one of those semantic styles is mapped to a vibrant variant
      // and lands at about a fifth of full strength — the bar came out light grey under
      // digits drawn in solid black. The concrete system colour is left alone, and it still
      // follows the colour scheme, so the bar matches the altitude it bounds in both.
      .foregroundStyle(Color(uiColor: .label))
  }
}
