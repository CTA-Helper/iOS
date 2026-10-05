import Foundation
import NavDataSchema

extension NavDataReleaseManifest {
  /// The URL of the newest published manifest.
  private static let releaseURL = URL(
    string: "https://github.com/CTA-Helper/Navdata/releases/latest/download/manifest.json"
  )!

  /// The URL of the newest published data file.
  private static let releaseDataURL = URL(
    string: "https://github.com/CTA-Helper/Navdata/releases/latest/download/cta-navdata.json.gz"
  )!

  /// Where the manifest is fetched from: the newest release, or the fixture a UI test serves.
  static var url: URL { UITestConfiguration.navData?.manifestURL ?? releaseURL }

  /// Where the data file is fetched from, following ``url``.
  static var dataURL: URL { UITestConfiguration.navData?.dataURL ?? releaseDataURL }
}
