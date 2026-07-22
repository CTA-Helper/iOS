# SwiftData models

- Don't put `CodingKeys` on a SwiftData-stored type: SwiftData stores `Codable`
  composites by property name, and a rename silently round-trips back as `nil`.
  The wire keys belong on a DTO — see `NavData/CLAUDE.md`.
- Store a value that pairs with a discriminator as an enum with associated
  values (`PublishedAltitude`, `ReferenceAltitude`), so a second altitude with no
  first, or a source naming a fix that published nothing, cannot be represented.
- Don't reference an enum with associated values from a `#Predicate` — it's
  unsupported. Anything filtered or sorted on stays a plain stored scalar.
  Today every predicate and `#Unique` is on `Airport`'s `siteNumber`,
  identifiers, or name.
