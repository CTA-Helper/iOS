import BackgroundTasks
import Foundation
import NavDataSchema
import SwiftData
import os

/**
 Replaces the nav data in the background once its cycle has lapsed, so a returning pilot finds
 the current cycle already installed.

 The task is registered declaratively by a scene modifier on ``CTA_HelperApp`` and submitted
 here. An update runs for longer than an app refresh allows, so it asks for the long window iOS
 grants a device on its charger with a network. It never runs before the pilot's first load, and
 keeps to networks iOS does not treat as metered unless the pilot has allowed them.

 It is not guaranteed to run. It is an optimization over the on-launch path, which still offers
 the pilot any update the background did not get to.
 */
@MainActor
final class BackgroundRefreshScheduler {
  /// Shared singleton owning background-refresh scheduling.
  static let shared = BackgroundRefreshScheduler()

  /**
   The processing-task identifier for replacing lapsed nav data, matched by the Info.plist
   `BGTaskSchedulerPermittedIdentifiers` array and the `.backgroundTask(.processingTask(_:))`
   scene modifier.
   */
  static let navDataRefreshIdentifier = "codes.tim.CTA-Helper.navdata-processing"

  private let logger = Logger(subsystem: "codes.tim.CTA-Helper", category: "BackgroundRefresh")

  /**
   Whether background work should run.

   Inert under UI testing, so XCTest's wait-for-idle never stalls on background work and no
   `BGTaskRequest` is submitted during a test run.
   */
  private var isEnabled: Bool { !UITestConfiguration.isRunning }

  /**
   The networks a background update may use: those iOS does not treat as metered, and metered
   ones too once the pilot has allowed them.
   */
  private var backgroundNetworkAccess: NavDataNetworkAccess {
    UserDefaults.standard.bool(forKey: SettingsKey.allowsBackgroundMeteredDownloads)
      ? .any : .unmeteredOnly
  }

  private init() {}

  /**
   Plans the refresh from the generation of nav data active on disk.

   The app's own container can still be reading a generation an earlier background update
   replaced — it reopens only while its scene is running — and a plan read from it would find the
   replaced data stale and download it again. This opens the active generation itself, away from
   the main actor.

   - Returns: The plan, or ``NavDataRefreshPlan/none`` when no generation is installed.
   */
  @concurrent
  nonisolated private static func planFromActiveGeneration() async throws -> NavDataRefreshPlan {
    let container: ModelContainer
    do {
      container = try NavDataStore.makeContainerForExistingGeneration(
        layout: NavDataStore.layout,
        generation: NavDataStore.activeGeneration
      )
    } catch NavDataStore.Errors.navDataStoreIsMissing {
      return .none
    }
    return NavDataRefreshPlan(try NavDataState.fetch(context: ModelContext(container)))
  }

  /**
   Submits a processing request to replace the nav data once its cycle lapses.

   The request needs external power and a network, and starts no earlier than the moment the
   installed cycle expires. Data already out of date asks to start as soon as iOS allows, and a
   device with no data installed submits nothing.
   */
  func scheduleNavDataRefresh() async {
    guard isEnabled else { return }

    let plan: NavDataRefreshPlan
    do { plan = try await Self.planFromActiveGeneration() } catch {
      logger.notice("Couldn’t plan a nav data refresh: \(error.localizedDescription)")
      return
    }

    let request = BGProcessingTaskRequest(identifier: Self.navDataRefreshIdentifier)
    request.requiresNetworkConnectivity = true
    request.requiresExternalPower = true
    switch plan {
      case .none: return
      case .now: request.earliestBeginDate = nil
      case .at(let expires): request.earliestBeginDate = expires
    }
    await submit(request)
  }

  /**
   Replaces the nav data if it has lapsed, then schedules the next refresh.

   SwiftUI marks the underlying `BGTask` complete when this returns and cancels the backing Swift
   `Task` on expiration. That cancellation stops the update, which leaves nothing behind but a
   generation the next launch reclaims: the data in use is only replaced once the new data is
   whole.
   */
  func handleNavDataRefresh() async {
    guard isEnabled else { return }

    do {
      guard try await Self.planFromActiveGeneration() == .now else {
        logger.debug("Nav data is current; nothing to refresh.")
        await scheduleNavDataRefresh()
        return
      }
      try await NavDataUpdater.shared.update(networkAccess: backgroundNetworkAccess)
      logger.notice("Replaced the nav data in the background.")
    } catch {
      logger.notice("Background nav data refresh stopped: \(error.localizedDescription)")
    }
    await scheduleNavDataRefresh()
  }

  /**
   Submits a background task request, logging rather than reporting a refusal.

   A request for a task already pending replaces it.
   */
  private func submit(_ request: BGTaskRequest) async {
    do {
      try await BGTaskScheduler.shared.submitTaskRequest(request)
      logger.debug("Scheduled the nav data refresh.")
    } catch {
      logger.notice("Could not schedule the nav data refresh: \(error.localizedDescription)")
    }
  }
}
