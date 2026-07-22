# Wire shape

- Decode the release JSON into a DTO in `NavDataDocument.swift` under its bare
  wire names, and map it to the suffixed model, like `AirportDTO` / `FixDTO` /
  `ReferenceAltitudesDTO`. `CodingKeys` on a DTO is fine — a DTO is never stored,
  so it never round-trips through SwiftData.
- Normalize here, once: a wire field that pairs a value with a discriminator
  (`altitude` / `altitude2` / `altitudeDescription`; reference `altitude` +
  `source`) becomes the model's enum with associated values in
  `AltitudeDescription.publishedAltitude(altitudeFt:altitude2Ft:)` and
  `ReferenceDTO.model`. Nothing downstream should see the loose shape.
- Decode leniently where a bad record costs one leg, and strictly where it costs
  a correction: an unrecognized altitude description or role reads as a safe
  default, but a negative sequence number fails the import rather than dropping
  a fix the pilot would then fly without.
