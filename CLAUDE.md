# CTA Helper

## Physical values

Physical value = scalar with a convertible unit (length, temperature, speed,
pressure). Not physical: `latitude` / `longitude`, counts, indices, sequence
numbers, fractions, `Date` / `Duration`.

- Name every physical value either `Measurement<Dimension>` or a primitive
  suffixed with the abbreviated unit (`Ft`, `NM`, `C`, `Kts`, `Deg`, PascalCase:
  `altitudeFt`, `temperatureC`).
- Use `Measurement` everywhere a physical value is named, including the
  correction engine and its arithmetic — `Support/Measurements.swift` supplies
  the `.feet` / `.celsius` factories and the rounding Foundation doesn't. Format
  with `.measurement` + `usage: .asProvided` so the locale can't convert feet.
- Use unit-suffixed primitives in exactly three places: SwiftData `@Model`
  stored properties, Codable DTO fields, and the body of a low-level pure
  function (`ColdTemperatureCorrection.correctionFt`, `BoundingBox`).
- Keep the `Measurement`-to-primitive conversion monotonic and downstack. A
  stored primitive becomes a `Measurement` once, at one named accessor
  (`Airport.elevation`, `PublishedAltitude.correctable`); a `Measurement`
  becomes a primitive only on the way into a pure function or into the one
  control that can't hold it (`Slider`, `MeasurementField`). Never round-trip
  `Measurement` → primitive → `Measurement` to move a value between layers.
