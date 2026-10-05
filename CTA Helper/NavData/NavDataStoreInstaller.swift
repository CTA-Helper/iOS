import Foundation
import NavDataSchema
import SwiftData
import os

/**
 Switches the app to a newly written generation of the nav data store.

 Installing is a single `UserDefaults` write, and it happens only after the candidate has been
 opened and found to hold a dataset. Nothing is overwritten and nothing is deleted, so an update
 that fails — or is killed mid-flight when the pilot swipes the app away — leaves the dataset in
 use exactly as it was.
 */
struct NavDataStoreInstaller {
  private static let logger = Logger(
    subsystem: "codes.tim.CTA-Helper",
    category: "NavDataStoreInstaller"
  )

  private let layout: StoreLayout
  private let defaults: UserDefaults

  /// The generation currently in use.
  var activeGeneration: Int { defaults.activeNavDataGeneration }

  /**
   - Parameters:
     - layout: Where the stores live.
     - defaults: Where the active generation is recorded.
   */
  init(layout: StoreLayout, defaults: UserDefaults = .standard) {
    self.layout = layout
    self.defaults = defaults
  }

  /**
   A generation number no store is using, for an update to write.

   Numbers rise rather than alternate, so a generation the views still hold open is never reused
   underneath them.
   */
  func reserveGeneration() -> Int {
    let next = max(activeGeneration, layout.navStoreGenerations().max() ?? 0) + 1
    StoreLayout.removeStore(at: layout.navStoreURL(generation: next))
    return next
  }

  /**
   Switches to `generation`, if the store it names holds a usable dataset.

   - Parameter generation: The generation an update has just written.
   - Throws: ``Errors/storeIsEmpty`` if the candidate holds no airports,
     ``NavDataStore/Errors/navDataStoreIsMissing(generation:)`` if its store has gone from disk,
     or the error SwiftData raised trying to open it.
   */
  func install(generation: Int) throws {
    try validate(generation: generation)
    activate(generation: generation)
  }

  /**
   Opens a candidate generation and confirms it holds a dataset.

   Opening it here, through the same configuration the app reads with, is what turns a store this
   binary cannot read into a failed install rather than a broken launch. It is opened as a
   generation that must already be on disk: bootstrapping an empty one in place of a candidate
   that has gone would refuse the install for the wrong reason, and leave a file behind that
   nothing wrote.

   - Parameter generation: The generation an update has just written.
   - Throws: The errors ``install(generation:)`` does.
   */
  func validate(generation: Int) throws {
    let container = try NavDataStore.makeContainerForExistingGeneration(
      layout: layout,
      generation: generation
    )
    guard try ModelContext(container).fetchCount(FetchDescriptor<Airport>()) > 0 else {
      throw Errors.storeIsEmpty
    }
  }

  /**
   Switches to `generation` without checking it, for a caller that has just done so with
   ``validate(generation:)``.
   */
  func activate(generation: Int) {
    defaults.navDataSchemaVersion = NavDataSchema.version
    defaults.activeNavDataGeneration = generation
    Self.logger.notice("Switched to nav data generation \(generation, privacy: .public)")
  }

  /// Reasons a candidate store was refused.
  enum Errors: LocalizedError {
    /// The store held no airports.
    case storeIsEmpty

    var errorDescription: String? {
      String(localized: "Couldn’t use the navigation data that was downloaded.")
    }

    var failureReason: String? {
      switch self {
        case .storeIsEmpty: String(localized: "The downloaded database contained no airports.")
      }
    }

    var recoverySuggestion: String? {
      String(localized: "Try downloading the navigation data again.")
    }
  }
}
