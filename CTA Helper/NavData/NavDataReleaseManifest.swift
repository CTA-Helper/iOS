import Foundation
import NavDataSchema

extension NavDataReleaseManifest {
  /// Where Navdata publishes its releases, each tagged with the date its cycle takes effect.
  private static let releasesURL = URL(string: "https://github.com/CTA-Helper/Navdata/releases/")!

  private static let manifestFilename = "manifest.json"
  private static let dataFilename = "cta-navdata.json.gz"

  /**
   The newest release's manifest, for when the cycle in force has no release of its own.

   Navdata publishes each cycle the day before it takes effect, so the newest release is not the
   one to ask for first: for most of that day it is a cycle not yet in force.
   */
  static var latestURL: URL {
    UITestConfiguration.navData?.manifestURL
      ?? releasesURL.appending(path: "latest/download/\(manifestFilename)")
  }

  /// Where the data file this manifest describes is fetched from: the same release.
  var dataURL: URL {
    UITestConfiguration.navData?.dataURL
      ?? Self.releaseURL(effective: cycleEffective, file: Self.dataFilename)
  }

  /**
   The manifest of the release for the cycle in force at `date`, or the fixture a UI test serves.

   - Parameter date: The moment to find the cycle in force at.
   */
  static func url(inForceAt date: Date) -> URL {
    UITestConfiguration.navData?.manifestURL
      ?? releaseURL(
        effective: AIRACCalendar.effectiveDates(at: date, count: 1)[0],
        file: manifestFilename
      )
  }

  private static func releaseURL(effective: Date, file: String) -> URL {
    releasesURL.appending(
      path: "download/\(NavDataStoreManifest.cycleName(effective: effective))/\(file)"
    )
  }
}
