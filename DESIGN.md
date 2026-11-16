---
name: BroClean native macOS
description: Compact browser-source index with explicit, reviewable cleanup.
colors:
  accent: "rgb(19.6% 40% 65%)"
  ink-light: "rgb(14% 30% 49%)"
  ink-dark: "rgb(66% 79% 96%)"
  pale: "rgb(19.6% 40% 65% / 6.5%)"
  soft: "rgb(19.6% 40% 65% / 13%)"
  on-accent: "white"
typography:
  title:
    fontFamily: "system-ui"
    fontSize: "19pt"
    fontWeight: 600
  review-title:
    fontFamily: "system-ui"
    fontSize: "17pt"
    fontWeight: 600
  source-title:
    fontFamily: "system-ui"
    fontSize: "13pt"
    fontWeight: 600
  body:
    fontFamily: "system-ui"
    fontSize: "12pt"
    fontWeight: 400
  memory:
    fontFamily: "system-ui"
    fontSize: "12pt"
    fontWeight: 500
  supporting:
    fontFamily: "system-ui"
    fontSize: "11pt"
    fontWeight: 400
  label:
    fontFamily: "system-ui"
    fontSize: "10pt"
    fontWeight: 400
rounded:
  cleanup: "6pt"
  panel: "10pt"
spacing:
  text-stack: "4pt"
  columns: "6pt"
  detail-stack: "7pt"
  source-content: "8pt"
  row-inset: "12pt"
  header-inset: "14pt"
components:
  panel:
    width: "400pt"
    rounded: "{rounded.panel}"
  header:
    backgroundColor: "{colors.pale}"
    padding: "{spacing.header-inset}"
  group-band:
    backgroundColor: "{colors.soft}"
    typography: "{typography.supporting}"
    padding: "3pt 11pt 3pt 14pt"
  browser-row:
    padding: "{spacing.row-inset}"
  browser-row-protected:
    backgroundColor: "{colors.pale}"
    padding: "{spacing.row-inset}"
  cleanup-menu:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.on-accent}"
    rounded: "{rounded.cleanup}"
    padding: "7pt 9pt"
  close-review:
    width: "360pt"
    padding: "22pt"
---

# Design System: BroClean

## Overview

**Creative North Star: "Compact index of browser ownership"**

BroClean uses a restrained native Mac surface to make browser sources and their current state easy to scan. Quiet blue tints organize information; monochrome source marks and aligned resource figures give the list its character. Consequential actions reveal their scope before execution.

This is a code-led record of the approved scheme 2 direction, extracted from `Sources/BrowserScopeApp/BrowserPanel.swift` and `App.swift`. The native application is the authority here. The companion HTML preview is a separate, simulated presentation and does not define native control rendering, responsive behavior, or accessibility. No approved image comp governs this build. The approved launch icon is option A, stacked browser windows on a blue tile, shipped from version 0.3.0; the menu-bar symbol remains the system globe.

**Key Characteristics:**
- Native macOS controls and system typography.
- Restrained blue accent with appearance-aware ink and translucent grouping.
- Monochrome source cues, aligned values, and visible uncertainty.
- Reviewable close actions with visible protection and exclusions.

## Colors

### Primary

`accent` is the implemented blue, expressed in the frontmatter with the exact RGB fractions used by SwiftUI. The direction contract's rounded hex shorthand is not a second source of truth. `pale` supplies header, footer, notices, expanded rows and protected rows; `soft` supplies group bands and the busy strip. These overlays blend with the active native surface.

`ink-light` and `ink-dark` are the two branches of `Theme.ink`, selected through AppKit appearance matching. Apply the dynamic binding to titles, marks, resource emphasis and group bands; do not freeze the light branch in dark appearance.

### Neutral

The panel uses `NSColor.windowBackgroundColor`. Ordinary text and dividers retain SwiftUI's semantic styling; secondary descriptions use `.secondary`. These are OS-resolved colors, deliberately not fabricated fixed CSS swatches. `on-accent` is used on the cleanup menu label. Destructive review uses SwiftUI `.red`, not a custom brand color.

**The Semantic Surface Rule.** Preserve the native window background, semantic text styles and appearance-aware ink together; a fixed background or fixed ink branch breaks their relationship.

## Typography

SwiftUI `.system` provides San Francisco on macOS. The frontmatter's `system-ui` is the portable family description, not a web-font dependency. Dimensions are native points. There is no custom line-height, tracking, font pairing or proportional type scale.

The title and review-title roles establish identity and the confirmation hierarchy. Source titles use semibold emphasis; supporting text carries summaries, evidence, notices and footer information. Compact labels include column headings and browser/mode metadata. Page counts use regular system type at (13pt); memory uses its medium role. Both counts and memory use monospaced digits, without changing the surrounding type to a monospaced family. Group names and selected supporting headings use semibold (11pt); the cleanup label uses medium (11pt).

These sizes describe the reviewed native implementation. They are not web minimum-size guidance; the companion has its own CSS and review evidence.

## Layout

The current native panel is a fixed-width vertical index: header, column labels, scroll area, conditional busy strip, footer. Its scroll area is (370pt) tall; total panel height follows fitted content rather than the initial AppKit window rectangle. It has no mobile breakpoint.

The source column expands. Memory occupies (62pt), pages (32pt), and the header reserves (42pt) for trailing actions. Row content uses the row-inset token on both axes. Source marks have a (23pt) drawing area inside a (29 × 32pt) frame. The row divider begins at (49pt), aligning beneath the source text rather than the mark. Source names and subtitles truncate to one line; expanded details expose evidence.

Nonempty Automated, Personal and Other groups appear in enum order. Filters restrict the visible list, sorting operates within the resulting grouped presentation, and group counts describe visible rows. The footer's cleanup menu uses its separately defined global headless/automated eligibility and is not the same scope as a group X.

Review content has its own fixed width and padding tokens, with the target list capped at (260pt) height. Repository settings use native fields in a (340pt) view with (20pt) padding. Menu-bar positioning clamps to the screen's visible frame with (8pt) edge margins and a (6pt) anchor gap.

## Elevation & Depth

Tonal bands and native dividers separate content. No custom row shadows, blur, gradients or motion curves are implemented. AppKit enables the panel's system shadow; its numeric shadow parameters are OS-owned. Sheets, menus, focus and control state transitions use native behavior. Do not substitute a fabricated CSS shadow or animation token for that behavior.

## Shapes

The panel clips to its panel-radius token. The cleanup menu label uses its smaller radius token. Rows and group bands remain contiguous rectangular list regions. Segmented filters, bordered confirmation buttons and the repository's rounded text field retain native geometry. Source marks are monochrome templates or SF Symbols rather than colored logo tiles.

## Components

### Header and filters

The title, refresh control, browser summary and total memory sit on the pale surface. Refresh has a (24 × 24pt) frame, help text, an accessibility label and the Command-R shortcut; busy or refresh state disables it. The segmented All / Automated / Headless picker uses native small controls. Sorting uses a native borderless menu with a (22pt) frame.

### Group band

Each nonempty group has a count and trailing X with a (25 × 25pt) frame. Dynamic ink and the soft tint establish grouping. The X is disabled while busy or when no eligible targets remain; its help and accessibility label explain scope.

**The Visible Group Rule.** A group X freezes the currently filtered group's eligible targets into a review sheet; it never silently expands the selection when the process list changes.

### Browser row and source mark

The source/title area toggles details as a plain button. Memory and page columns align across rows. Protected or expanded rows gain the pale tint; protection also has a lock, so color is not the sole signal. The separate close control is (22 × 28pt); the overflow menu supplies details, persistent protection, normal close and explicit force quit.

Claude and ChatGPT use bundled template images. Codex and Terminal use `terminal`; Playwright and Puppeteer use `theatermasks`; Safari uses `safari`; other sources use `globe`. Marks are iconographic cues, not guaranteed application attribution or a complete set of official logos. They are accessibility-hidden because the adjacent source label supplies the identity. Inferred attribution is stated in accessibility text, help and expanded evidence. Unknown page counts show an em dash; partial available memory carries a plus marker.

### Cleanup and settings

The accent-filled cleanup menu is the strongest persistent control. Its two options review eligible headless or automated browsers. The protected count uses dynamic ink and a lock. The settings gear opens a native menu for version, repository, login, About and quit; repository editing uses a native rounded text field and validated Save action. There is no custom navigation bar, card system or chip component.

### Close review

Native sheets list frozen targets by source, browser, PID and mode, followed by skipped items. A personal-browser target produces the active-work warning. Cancel supports Escape; the destructive counted button requires an explicit click. Force quit has a separate warning and action. Group protection is checked again before execution, including fail-closed behavior when protection cannot be read. Persistent protection applies to group/bulk cleanup; an explicitly reviewed individual close remains available subject to core safety exclusions.

### Feedback and progress

Scanning and empty states include both a symbol and text. Notices and last-action results are dismissible, selectable text on the pale surface. Busy state exposes progress and Stop remaining, changing to Stopping… when requested. It disables conflicting close actions. Demo operations report that no processes were closed.

## Do's and Don'ts

### Do:
- **Do** retain native controls, keyboard access and semantic appearance bindings.
- **Do** pair monochrome source cues with readable names and inspectable attribution evidence.
- **Do** preserve aligned resource values, unknown dashes and partial-memory markers.
- **Do** show frozen group targets, exclusions and personal-browser warnings before closure.
- **Do** preserve a lock as well as tint for protection.

### Don't:
- **Don't** treat source marks as proof of ownership or inference as certainty.
- **Don't** promote companion HTML measurements or browser control styles into the native system.
- **Don't** imply that protection blocks an explicitly reviewed individual close.
- **Don't** turn a group X into immediate or automatic termination.
- **Don't** replace the approved A launch icon with an unapproved candidate.
