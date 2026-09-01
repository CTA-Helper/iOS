import Foundation

extension SettingsKey {
  /// The pilot's favorited airport site numbers (``AirportIDList``).
  static let favoriteAirports = "favoriteAirports"
  /// The most recently opened airport site numbers, newest last (``AirportIDList``).
  static let recentAirports = "recentAirports"
}

/// The number of recent airports kept.
private let recentAirportsLimit = 10

/**
 An ordered list of airport site numbers persisted in `@AppStorage`.

 Site numbers, not codes: a list saved against `KPBI` would have gone dangling the day Palm
 Beach became `KDJT`.

 `@AppStorage` stores a `RawRepresentable` whose `RawValue` is `String`, so the list is
 encoded as a JSON array string. This wrapper avoids a retroactive conformance on `Array`.
 */
struct AirportIDList: RawRepresentable, Codable, Equatable, Sendable {
  var ids: [String]

  var rawValue: String {
    guard let data = try? JSONEncoder().encode(ids),
      let json = String(data: data, encoding: .utf8)
    else {
      preconditionFailure("A list of airport site numbers cannot fail to encode as UTF-8 JSON")
    }
    return json
  }

  init(_ ids: [String] = []) {
    self.ids = ids
  }

  init?(rawValue: String) {
    guard let data = rawValue.data(using: .utf8),
      let ids = try? JSONDecoder().decode([String].self, from: data)
    else { return nil }
    self.ids = ids
  }

  /// Whether the list contains an identifier.
  func contains(_ id: String) -> Bool { ids.contains(id) }

  /// Add or remove an identifier, returning the updated list.
  func toggling(_ id: String) -> Self {
    Self(contains(id) ? ids.filter { $0 != id } : ids + [id])
  }

  /// Add an identifier if the list does not already carry it.
  func adding(_ id: String) -> Self {
    contains(id) ? self : Self(ids + [id])
  }

  /// Move an identifier to the end (most recent), dropping the oldest beyond `recentAirportsLimit`.
  func appendingRecent(_ id: String) -> Self {
    var updated = ids.filter { $0 != id }
    updated.append(id)
    if updated.count > recentAirportsLimit {
      updated.removeFirst(updated.count - recentAirportsLimit)
    }
    return Self(updated)
  }
}

extension UserDefaults {
  /**
   The airports to offer where something has to offer a few: the starred ones, or the recently
   opened where none are starred.

   Shortcuts fills its picker from this list, so it has to be short and it has to be the airports
   this pilot flies. The twenty thousand US landing facilities are neither.
   */
  var suggestedAirportIDs: [String] {
    let favorites = airportIDList(forKey: SettingsKey.favoriteAirports).ids
    guard favorites.isEmpty else { return favorites }
    return airportIDList(forKey: SettingsKey.recentAirports).ids.reversed()
  }

  /**
   The airport list stored under a key.

   `@AppStorage` reads and writes the same JSON string, so a list written here reaches every view
   observing the key. It is what the router uses, which is outside a `View` and so has no
   `@AppStorage` of its own.

   - Parameter key: the settings key to read.
   - Returns: the stored list, or an empty one where nothing readable is stored.
   */
  func airportIDList(forKey key: String) -> AirportIDList {
    string(forKey: key).flatMap(AirportIDList.init(rawValue:)) ?? .init()
  }

  /// Store an airport list, in the form `@AppStorage` reads back.
  func set(_ list: AirportIDList, forKey key: String) {
    set(list.rawValue, forKey: key)
  }
}
