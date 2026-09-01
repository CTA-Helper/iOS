import PDFKit
import SwiftUI

/**
 The approach plate itself, drawn by PDFKit.

 There is no SwiftUI view for a PDF, so this is the app's one bridge into UIKit besides
 ``ScreenAwake``. It stays deliberately thin: a plate is a single dense page the pilot pans and
 zooms, so the view offers scrolling and scaling and nothing else.
 */
struct PlateView: UIViewRepresentable {
  /**
   How far past a fit the pilot may zoom.

   A plate's minima table is set in type that is unreadable at fit width on a phone, so the
   ceiling has to be well above the "size to fit" scale rather than near it.
   */
  private static let maximumScale: CGFloat = 12

  /// The plate on disk.
  let plate: URL

  func makeUIView(context _: Context) -> PDFView {
    let view = PDFView()
    view.displayMode = .singlePageContinuous
    view.displayDirection = .vertical
    view.pageShadowsEnabled = false
    view.backgroundColor = .systemBackground

    // Assigning either scale bound implicitly turns `autoScales` off, so the bounds are set
    // first and the plate is told to fit the width afterwards.
    view.minScaleFactor = view.scaleFactorForSizeToFit
    view.maxScaleFactor = Self.maximumScale
    view.autoScales = true

    view.document = PDFDocument(url: plate)
    return view
  }

  /**
   Reload only when the plate itself changed.

   Assigning a document unconditionally would re-parse a megabyte on every SwiftUI update and
   throw away wherever the pilot had zoomed to — which, on this screen, is the whole of what
   they were doing.
   */
  func updateUIView(_ view: PDFView, context _: Context) {
    guard view.document?.documentURL != plate else { return }
    view.document = PDFDocument(url: plate)
  }
}
