# CTA Helper

## Physical values

Physical value = scalar with a convertible unit (length, temperature, speed,
pressure). Not physical: `latitude` / `longitude`, counts, indices, sequence
numbers, fractions, `Date` / `Duration`.

- Name every physical value either `Measurement<Dimension>` or a primitive
  suffixed with the abbreviated unit (`Ft`, `NM`, `C`, `Kts`, `Deg`, PascalCase:
  `altitudeFt`, `temperatureC`).
- Use `Measurement` in the view layer and in public API. Format with
  `.measurement` + `usage: .asProvided` so the locale can't convert feet.
- Use unit-suffixed primitives in the correction engine, SwiftData `@Model`
  stored properties, and Codable DTO fields. Convert at the view boundary.
