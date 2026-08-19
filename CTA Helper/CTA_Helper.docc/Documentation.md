# ``CTA_Helper``

FAA cold temperature altitude corrections for the altitudes of an instrument approach,
following the method published in AIP ENR 1.8.

## Overview

A barometric altimeter assumes a standard atmosphere. In air colder than standard the column is
denser, the altimeter reads high, and the aircraft is lower than it indicates. At a Cold
Temperature Restricted Airport that means computing a correction for every published altitude on
the approach and adding it — segment by segment, off a temperature read from a METAR, in the
cockpit. The app does that arithmetic.

It is for situational awareness and planning only, not for primary navigation.

## Topics

### Correcting an approach

- ``ColdTemperatureCorrection``
- ``ApproachCorrector``
- ``Correction``
- ``CorrectionMethod``
- ``CorrectionRounding``

### Nav data

- ``NavDataLoader``
- ``NavDataDocument``
- ``NavDataCycle``
- ``Airport``
- ``Approach``

### Weather

- ``METARLoader``
