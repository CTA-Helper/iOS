import CoreLocation
import Foundation
import Gzip

#if DEBUG

  /**
   The state a UI test asks the app to launch in, read from its launch arguments.

   A UI test drives the app from a separate process and cannot reach into it, so whatever has to
   be settled before the first screen draws — what the store holds, where the nav data comes
   from, what Core Location reports — arrives on the command line and is read here. Launched the
   way a pilot launches it, with none of these arguments, every property below is `nil` or
   `false` and the app runs against its own store, the published nav data, and the real device.

   Each argument is a bare flag rather than a name/value pair: `UserDefaults` claims `-key value`
   pairs off the command line and registers them as defaults, which would put a test's own
   arguments into the settings the app reads.
   */
  enum UITestConfiguration {
    private static let argumentPrefix = "-uiTest"

    private static let arguments = Set(ProcessInfo.processInfo.arguments)

    /// Whether a UI test is driving the app, and so the pilot's own store must be left untouched.
    static var isRunning: Bool { arguments.contains { $0.hasPrefix(argumentPrefix) } }

    /// Whether the store opens seeded with sample airports rather than empty.
    static var seedsStore: Bool { arguments.contains("\(argumentPrefix)Seed") }

    /// What ``NavDataLoader`` fetches, in place of the published release.
    static var navData: NavDataFixture? {
      if arguments.contains("\(argumentPrefix)NavDataBundled") { return .bundled }
      if arguments.contains("\(argumentPrefix)NavDataUnreachable") { return .unreachable }
      return nil
    }

    /**
     The location source to inject, or `nil` to leave the device's own in place.

     A UI test cannot answer the system permission alert, so a test that means to reach the
     Nearest tab says up front what location reports.
     */
    @MainActor static var locationStreamer: FixedLocationStreamer? {
      if arguments.contains("\(argumentPrefix)LocationAuthorized") {
        return FixedLocationStreamer(
          authorizationStatus: .authorizedWhenInUse,
          location: .nearMissoula
        )
      }
      if arguments.contains("\(argumentPrefix)LocationDenied") {
        return FixedLocationStreamer(authorizationStatus: .denied)
      }
      return nil
    }

    /// Where a UI test serves a nav data cycle from, in place of the published release.
    enum NavDataFixture {
      /// The sample cycle bundled with the app, which downloads and imports the way a release does.
      case bundled
      /// A path nothing answers, so the download fails and the loading screen reports it.
      case unreachable

      /// The bundled cycle compressed once, with what a manifest has to say about those bytes.
      private static let packedFixture = PackedFixture()

      /// The bundled manifest with ``packedFixture``'s real digest and sizes patched into it.
      private static let packedManifest: URL = {
        do {
          let source = try Data(contentsOf: bundled("uiTestManifest"))
          guard var manifest = try JSONSerialization.jsonObject(with: source) as? [String: Any],
            var data = manifest["data"] as? [String: Any]
          else {
            preconditionFailure("uiTestManifest.json is not the shape the loader reads")
          }

          data["bytes"] = packedFixture.bytes
          data["uncompressedBytes"] = packedFixture.uncompressedBytes
          data["sha256"] = packedFixture.sha256
          manifest["data"] = data

          let url = URL.temporaryDirectory.appending(component: "uiTestManifest.json")
          try JSONSerialization.data(withJSONObject: manifest).write(to: url)
          return url
        } catch {
          preconditionFailure("Could not build the nav data fixture manifest: \(error)")
        }
      }()

      /**
       The manifest describing ``dataURL``, with the digest and byte counts of the bytes actually
       packed rather than the placeholders the bundled copy carries.

       The loader verifies every download against its manifest, and the fixture is compressed at
       runtime, so the digest cannot be committed — gzip output depends on the compressor. Filling
       it in from the packed bytes is what lets a UI test walk the same verification a real
       download walks, rather than the test being the one path that skips it.
       */
      var manifestURL: URL {
        switch self {
          case .bundled: Self.packedManifest
          case .unreachable: Self.unreachable("uiTestManifest.json")
        }
      }

      /**
       The cycle itself, packed the way the release is published.

       The fixture is bundled as plain JSON and compressed here rather than committed compressed:
       the loader gunzips whatever it downloads, but a blob no reviewer can read against the wire
       format is a poor thing to keep a wire format's test in.
       */
      var dataURL: URL {
        switch self {
          case .bundled: Self.packedFixture.url
          case .unreachable: Self.unreachable("uiTestNavData.json.gz")
        }
      }

      private static func bundled(_ name: String) -> URL {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
          preconditionFailure("\(name).json is missing from the app bundle")
        }
        return url
      }

      private static func unreachable(_ name: String) -> URL {
        URL(fileURLWithPath: "/no/such/directory/\(name)")
      }

      /// The bundled cycle written out compressed, alongside what a manifest publishes about it.
      struct PackedFixture {
        /// Where the compressed cycle was written, for the loader to "download".
        let url: URL
        /// The compressed length, which the manifest publishes as `bytes`.
        let bytes: UInt
        /// The decompressed length, which the manifest publishes as `uncompressedBytes`.
        let uncompressedBytes: UInt
        /// The digest of the compressed bytes, which the manifest publishes as `sha256`.
        let sha256: String

        init() {
          do {
            let raw = try Data(contentsOf: bundled("uiTestNavData"))
            let compressed = try raw.gzipped()
            let url = URL.temporaryDirectory.appending(component: "uiTestNavData.json.gz")
            try compressed.write(to: url)

            self.url = url
            bytes = UInt(compressed.count)
            uncompressedBytes = UInt(raw.count)
            sha256 = NavDataIntegrity.sha256(of: compressed)
          } catch {
            preconditionFailure("Could not pack the nav data fixture for download: \(error)")
          }
        }
      }
    }
  }

#else

  /**
   The state a UI test asks the app to launch in.

   A release build has no test hooks at all: nothing reads the command line, no fixture is
   reachable, and every hook below is a compile-time constant the optimizer folds away. The type
   stays so its call sites need no `#if` of their own.
   */
  enum UITestConfiguration {
    /// Always `false`: a release build is never driven by a test.
    static var isRunning: Bool { false }

    /// Always `false`: the store a release build opens is the pilot's own.
    static var seedsStore: Bool { false }

    /// Always `nil`: a release build fetches the published cycle and nothing else.
    static var navData: NavDataFixture? { nil }

    /// Always `nil`: a release build reads the device's own location.
    @MainActor static var locationStreamer: FixedLocationStreamer? { nil }

    /// Uninhabited, so no release build can name a fixture to serve.
    enum NavDataFixture {
      var manifestURL: URL { switch self {} }
      var dataURL: URL { switch self {} }
    }
  }

#endif
