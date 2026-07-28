# Marketing site

The site at <https://cta-helper.github.io/iOS/>, served by GitHub Pages from
`docs/` on `main`. Plain HTML, CSS and JavaScript with no build step and no
Jekyll — `.nojekyll` turns that processing off — so a push to `main` is the
whole deployment, and opening a file in a browser is the whole preview.

| File | |
| --- | --- |
| `index.html` | The page. |
| `privacy.html` | The privacy policy the app and App Store Connect link to. |
| `styles.css` | Everything visual. Tokens are the `:root` block at the top. |
| `main.js` | The step gallery and the diagram's temperature slider. |
| `og.html` | Source of the social card; not part of the site. |
| `sitemap.xml` | Submitted by hand — see below. |

## Editing

The page degrades to working HTML with the stylesheet and script removed, and
the descent diagram is pre-rendered in `index.html` at −11 °C; `main.js` only
updates it as the slider moves. Keep it that way — the diagram is the first
thing a visitor sees, and it should not wait on JavaScript.

Two pairs of things have to be edited together:

- The FAQ in `index.html` is mirrored into a `FAQPage` JSON-LD block in the same
  file. Change a question or answer in one and change it in the other, or the
  structured data starts lying about the page.
- The three walkthrough screenshots are named in `SITE_SCREENS` in
  `fastlane/Fastfile`. Adding a step to the page means adding its screen there.

Fonts are served from `fonts/` rather than a font CDN, under the SIL Open Font
License. A page that says the app does not track you should not hand every
visitor's address to a third party to render itself; keep new assets local for
the same reason.

## Screenshots

`site_screenshots` captures the same screens as the App Store set in both
appearances and installs the three iPhone shots the page walks through, scaled
down, into `images/screenshots/{light,dark}/`, where the page picks between them
with `prefers-color-scheme`.

```sh
bundle exec fastlane site_screenshots                   # both appearances
bundle exec fastlane site_screenshots appearance:light  # just one
bundle exec fastlane install_site_screenshots           # re-install a capture
```

## Social card

`images/og-card.png` is the image every link preview shows. It is generated from
`og.html` — a 1200×630 page built from the same tokens and the same descent
diagram as the site — so when the design moves, the card is recaptured rather
than redrawn:

```sh
python3 -m http.server 8000            # from this directory
```

Then load `http://localhost:8000/og.html` at exactly 1200×630 and capture the
viewport to `images/og-card.png`. A 2× capture is fine and preferred; the
`og:image:width` and `og:image:height` tags in `index.html` and `privacy.html`
must match whatever it actually is.

## Metadata

Both pages carry a canonical link, the Open Graph and Twitter card sets, and
`theme-color` for each colour scheme. `index.html` also carries `MobileApplication`
and `FAQPage` JSON-LD.

Every URL in that metadata must be **absolute**. Crawlers resolve them against
nothing, so a relative `og:image` means no link preview anywhere.

`sitemap.xml` has to be submitted to Google Search Console and Bing Webmaster
Tools by hand. Crawlers read `robots.txt` only from the domain root, and this is
a project page under `/iOS/`, so there is no `robots.txt` the sitemap could be
announced in — adding one here would be ignored.
