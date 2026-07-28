// Progressive enhancement only: every section is readable and navigable with this
// script absent. The profile diagram ships rendered at its default temperature.

const stampCurrentYear = () => {
  const year = String(new Date().getFullYear());
  document.querySelectorAll("[data-year]").forEach((el) => (el.textContent = year));
};

const wireNavToggle = () => {
  const toggle = document.querySelector(".nav-toggle");
  if (!toggle) return;

  const close = () => toggle.setAttribute("aria-expanded", "false");

  toggle.addEventListener("click", () => {
    const isOpen = toggle.getAttribute("aria-expanded") === "true";
    toggle.setAttribute("aria-expanded", String(!isOpen));
  });

  document.querySelector(".site-nav")?.addEventListener("click", (event) => {
    if (event.target.closest("a")) close();
  });
};

const wireGallery = (gallery) => {
  const tabs = [...gallery.querySelectorAll('[role="tab"]')];
  const panelFor = (tab) => document.getElementById(tab.getAttribute("aria-controls"));

  const select = (tab) => {
    tabs.forEach((other) => {
      const isSelected = other === tab;
      other.setAttribute("aria-selected", String(isSelected));
      other.tabIndex = isSelected ? 0 : -1;
      panelFor(other).hidden = !isSelected;
    });
  };

  const selectAndFocus = (tab) => {
    select(tab);
    tab.focus();
  };

  const tabAtOffset = (offset) =>
    tabs[(tabs.findIndex(isSelected) + offset + tabs.length) % tabs.length];

  const keyedTab = {
    ArrowRight: () => tabAtOffset(1),
    ArrowDown: () => tabAtOffset(1),
    ArrowLeft: () => tabAtOffset(-1),
    ArrowUp: () => tabAtOffset(-1),
    Home: () => tabs.at(0),
    End: () => tabs.at(-1),
  };

  tabs.forEach((tab) => {
    tab.addEventListener("click", () => select(tab));
    tab.addEventListener("keydown", (event) => {
      const target = keyedTab[event.key]?.();
      if (!target) return;
      event.preventDefault();
      selectAndFocus(target);
    });
  });
};

const isSelected = (tab) => tab.getAttribute("aria-selected") === "true";

/*
 * The profile diagram. Its geometry is a linear altitude axis of `SCALE` pixels per foot, with the
 * aerodrome elevation sitting on the ground line. Corrections are drawn at `EXAGGERATION` times
 * their true size — the liberty a published profile view takes, and why the chart says so.
 */

const AERODROME_FT = 3200;
const GROUND_Y = 356;
const SCALE = 0.0765;
const EXAGGERATION = 3;
const ISA_SEA_LEVEL_C = 15;
const ISA_LAPSE_C_PER_1000_FT = 1.98;

// The FAA's approximation: four feet per thousand feet above the aerodrome, per degree below ISA.
const FT_PER_1000_FT_PER_C = 4;

// The points both paths are pinned to. `labelX` is null where the drawing carries no altitude pair.
const PROFILE_FIXES = [
  { altitudeFt: 6000, labelX: 204 },
  { altitudeFt: 5000, labelX: 464 },
  { altitudeFt: 4200, labelX: 734 },
  { altitudeFt: 3600, labelX: null },
];

const BRACE_X = 190;
const MINIMUM_BRACE_HEIGHT = 18;

const isaTemperatureC = (altitudeFt) =>
  ISA_SEA_LEVEL_C - (ISA_LAPSE_C_PER_1000_FT * altitudeFt) / 1000;

const degreesBelowStandard = (reportedC) => isaTemperatureC(AERODROME_FT) - reportedC;

const correctionFt = (altitudeFt, reportedC) => {
  const heightFt = altitudeFt - AERODROME_FT;
  const raw = (FT_PER_1000_FT_PER_C * heightFt * degreesBelowStandard(reportedC)) / 1000;
  return Math.max(0, Math.round(raw / 10) * 10);
};

const publishedY = (altitudeFt) => GROUND_Y - (altitudeFt - AERODROME_FT) * SCALE;

const correctedY = (altitudeFt, reportedC) =>
  publishedY(altitudeFt) - EXAGGERATION * correctionFt(altitudeFt, reportedC) * SCALE;

const round = (value) => Number(value.toFixed(1));

// A level run at each fix, then a descent to the next, ending at the runway threshold.
const profilePath = ([iaf, intermediate, final, minimums]) =>
  `M 64 ${round(iaf)} H 250 L 450 ${round(intermediate)} H 510 L 720 ${round(final)} ` +
  `H 770 L 940 ${round(minimums)} L 1120 ${GROUND_Y}`;

const signed = (degreesC) => (degreesC < 0 ? `−${Math.abs(degreesC)}` : `${degreesC}`);

const readoutFor = (reportedC) =>
  `${signed(reportedC)} °C · ISA −${Math.round(degreesBelowStandard(reportedC))} °C`;

const describeProfile = (reportedC) => {
  const corrected = PROFILE_FIXES.filter((fix) => fix.labelX)
    .map((fix) =>
      (fix.altitudeFt + correctionFt(fix.altitudeFt, reportedC)).toLocaleString("en-US")
    )
    .join(", ");

  return (
    "Two descent paths step down toward a runway. The published path passes 6,000 feet at the " +
    "initial approach fix, 5,000 at the intermediate fix, and 4,200 at the final approach fix. " +
    `At ${reportedC} degrees Celsius the corrected path sits above it at ${corrected} feet, ` +
    "closing to nothing at the runway, because the correction shrinks with height above the " +
    "aerodrome."
  );
};

const wireProfile = (diagram) => {
  const slider = diagram.querySelector("[data-profile-temp]");
  const readout = diagram.querySelector("[data-profile-readout]");
  const path = diagram.querySelector("[data-profile-path]");
  const brace = diagram.querySelector("[data-profile-brace]");
  const delta = diagram.querySelector("[data-profile-delta]");
  const labels = [...diagram.querySelectorAll("[data-profile-label]")];
  const description = diagram.querySelector("[data-profile-description]");

  // The callout only reads as a measurement while there is a gap tall enough to draw it in.
  const drawCallout = (reportedC) => {
    const top = correctedY(PROFILE_FIXES[0].altitudeFt, reportedC);
    const bottom = publishedY(PROFILE_FIXES[0].altitudeFt);
    const tooShort = bottom - top < MINIMUM_BRACE_HEIGHT;

    brace.toggleAttribute("hidden", tooShort);
    delta.toggleAttribute("hidden", tooShort);
    if (tooShort) return;

    brace.setAttribute(
      "d",
      `M ${BRACE_X - 6} ${round(top)} h 12 M ${BRACE_X} ${round(top)} V ${round(bottom)} ` +
        `M ${BRACE_X - 6} ${round(bottom)} h 12`
    );
    delta.setAttribute("y", round((top + bottom) / 2 + 5));
    delta.textContent = `+${correctionFt(PROFILE_FIXES[0].altitudeFt, reportedC)} FT`;
  };

  const draw = (reportedC) => {
    const corrected = PROFILE_FIXES.map((fix) => correctedY(fix.altitudeFt, reportedC));
    path.setAttribute("d", profilePath(corrected));

    labels.forEach((label, index) => {
      const fix = PROFILE_FIXES[index];
      label.setAttribute("y", round(corrected[index] - 12));
      label.textContent = fix.altitudeFt + correctionFt(fix.altitudeFt, reportedC);
    });

    drawCallout(reportedC);

    readout.textContent = readoutFor(reportedC);
    slider.setAttribute("aria-valuetext", readoutFor(reportedC));
    description.textContent = describeProfile(reportedC);
  };

  slider.addEventListener("input", () => draw(Number(slider.value)));
  draw(Number(slider.value));
};

stampCurrentYear();
wireNavToggle();
document.querySelectorAll("[data-gallery]").forEach(wireGallery);
document.querySelectorAll("[data-profile]").forEach(wireProfile);
