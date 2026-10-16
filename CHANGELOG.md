# Changelog

## 1.7.2 — 2026-10-16

Register every working/tired companion to the same 33-unit visible height and align quota cards exactly from head to ground, restoring readable quota size. Increase Pet Only percentage typography and widen the mascot canvas to preserve character proportions without clipping wide pets. Keep mug spacing close and sleeping layout stable. Minimal quota typography is unchanged.

## 1.7.1 — 2026-10-16

Fit the standalone quota stack inside every standing companion’s visible silhouette using a shared 26-unit height instead of the 33-unit canvas estimate. Preserve card widths and stable layout across animals and sleeping states. Match quota typography and stack height to the Canvas’s actual pixel-snapped sprite scale at fractional sizes and 1×/2× display densities. Minimal and Expanded layouts are unchanged.

## 1.7.0 — 2026-10-16

Add separate early (25%) and critical (15%) quota notifications, exhaustion and confirmed renewal alerts. Persist delivery levels and last quota observations across restarts and temporary provider disconnections; retry failed notification submissions without bursts. Show macOS permission state and a test button in Settings → Behavior. Demo, stale and disabled quota sources never notify.

Remember positions separately for Minimal, Pet Only and Expanded using display UUIDs and relative visible-screen coordinates. Restore positions after display arrangement/resolution changes, recover safely if a monitor is absent, and retain the original monitor placement for reconnection. Keep existing preferences and migrate legacy frame storage. Suppress delegate saves during initial restoration so launching without the saved monitor does not replace its remembered position.

## 1.6.2 — 2026-10-16

Extract the quota accessibility-value formatter into a typed helper to avoid a Swift compiler type-check timeout on the GitHub-hosted Xcode toolchain. Visible quota content and behavior are unchanged.

## 1.6.1 — 2026-10-16

Order display choices consistently as Minimal, Pet Only, Expanded in settings, menu bar and context menu. Raise the shared size limit from 200% to 250%, preserving the current size selection. Extend persistence/scaling regression checks and 1×/2× previews through 250%.

## 1.6.0 — 2026-10-16

Add Minimal beside Expanded and Pet Only in settings, menu bar and widget context menu. A narrow mascot-free floating window shows selected providers' five-hour/weekly percentages and reset countdowns. Both providers use 120×91.2 points at 100%; a single provider shrinks to 120×48. Drag anywhere and right-click for refresh/settings/modes. Respect statistics visibility independently of pet visibility, suppress the expanded window, and keep minimal dragging available when pet click-through is enabled. Persist mode selection and retain original pet/attachment preferences for returning to other modes.

## 1.5.2 — 2026-10-15

Trim the standalone window's unused upper canvas instead of painting a smaller background inside the old hit area. Render the same artwork at the same scale through logical viewport y=15…49, with three-point vertical padding. Real window height at 100% shrinks from 119.25 to 76.125 points, preserving quota dimensions and ground alignment. Keep sleep markers inside the trimmed viewport. Add native top-left/top-right corner placement checks and a Core content-fit regression test. Both transparent and opaque modes use the tight window bounds.

## 1.5.1 — 2026-10-15

Use one shared quota-card scale for every animal, roughly 10% larger than the previous rabbit layout, with a common ground alignment. Remove artwork-height/display-density dependence from quota font/card sizing. Move mugs nearer the laptops and enlarge their pixel grids from 0.65 to 0.75 logical units. Retain four source pixels per logical unit for more detailed Retina sprites. Verify identical card geometry across twelve native renders and shared size scaling in Core.

## 1.5.0 — 2026-10-15

Apply the supplied right-facing Concept C character reference to all twelve companions and three activity states. Match charcoal/yellow-eyed cat, golden dog, side-view anatomy and cyan developer laptops. Position fixed, character-specific mugs to the right of the laptop with the reference's cat/bone/maple/bamboo/bunny/bear/moon/frog/fish/bin/orange/mountain emblems. Keep typing-only animation, no drinking/extra arms/physical props. Register each character's states to a shared crop footprint so sleeping does not resize the window or quota cards.

## 1.4.0 — 2026-10-15

Remove coffee drinking and articulated limb animation entirely. Keep one stationary, individually designed cup beside every animal. Clean bamboo, carrots, books, plants and the penguin's loose orange prop from all expression sprites, preserving animals and laptops. Working animation now consists of the existing typing paw and laptop caret, with faster/slower typing based only on five-hour quota. Sleeping does not type. Remove obsolete sip/yawn/ear/blink routines and replace them with continuous-typing, speed and inactive-state tests.

## 1.3.2 — 2026-10-15

Remove the procedural coffee arm entirely. Reuse each sprite's existing forepaw/wing with an individual contour and shoulder pivot, restore its covered body region, and move the cup with the painted paw. Draw the paw over the cup for a visible grip. Keep cups resting beside sleeping pets. Preserve all quota, mood, window and size behavior.

## 1.3.1 — 2026-10-15

Match the supplied motion sheet's white ceramic mug family with stepped outlines, hollow handles and narrow colored stripes. Keep animal customizations small: paw, heart, bamboo, star, lily, snowflake, mask, citrus and moon marks. Enlarge mugs slightly and align each lip to its animal's mouth. Add short pixel eyelid blinks, pointed-ear twitches and sleepy head-peek yawns. Increase coffee-break frequency without introducing whole-body bobbing. Preserve five-hour-only activity selection and shared layout dimensions. All 24 core tests and 47 native window checks pass.

## 1.3.0 — 2026-10-15

Redesign all twelve coffee cups as individual pixel props matched to each animal. Clean baked cups from the sprite atlas. Happy and tired pets pause typing, lift their cup, sip and set it down before resuming. Sleeping pets briefly lift their head and return to sleep without drinking. Keep the body/laptop fixed and five-hour-only activity thresholds. Add five routine timing tests and a twelve-animal visual sequence.

## 1.2.5 — 2026-10-15

Remove whole-character bobbing and head translation. Replace the moving rectangular image strip with a small paw-shaped keypress contour, leaving the body, head, feet and laptop stationary. Remove the colored strip below the laptop; use a stationary blinking caret inside the screen. Keep fast/slow/no typing based only on five-hour quota.

## 1.2.4 — 2026-10-15

Draw standalone text and cards at their final sizes rather than scaling composed layers. Render the mascot directly at the current display density, with physical-pixel alignment and crisp non-antialiased sprite masks/effects. Refresh SwiftUI display scale when crossing displays or backing densities. Add native 1×/2× previews at 50–200% sizes.

## 1.2.3 — 2026-10-15

Reduce the standalone mascot baseline from 144 to 132 points and widen the quota cards with larger percentages. Fit the complete quota stack to the actual rendered mascot silhouette, with vertical insets and a close horizontal gap. Preserve the shared size transform and fixed dimensions across activity states.

## 1.2.2 — 2026-10-15

Drive companion activity solely from the lowest fresh five-hour quota among enabled providers. Weekly quotas and display-window toggles no longer affect animation; missing five-hour data remains unknown. Weekly display and notifications are preserved.

## 1.2.1 — 2026-10-15

Make the cat charcoal black with green eyes and the dog golden yellow. Strengthen the classic pixel style with crisp cached pixel clusters. Animate actual head and paw regions of the new sprites: quick typing above 50%, slower occasional typing at 15–50%, and sleeping head nods/breathing below 15%. Keep the fixed state footprint and shared pet/quota scale.

## 1.2.0 — 2026-10-15

Apply the supplied Concept C reference boards: detailed 12-character pixel artwork with 36 expression assets, consistent state footprints, animated work/sleep effects, navy gradient surfaces, fine blue-purple borders, continuous quota bars, status bubble and eight theme preview cards. Preserve live integrations, reset countdowns, provider disclosures/selection, two display modes and shared sizing/dragging.


## 1.1.7 — 2026-10-14

Keep quota card scale and position constant across the 15% activity threshold. Replace the smaller lying-down sleep artwork with the full-size sitting companion: closed eyes, slow breathing and head nods, drifting Zs, dim laptop and no typing. Only the size setting changes the shared layout scale.

## 1.1.6 — 2026-10-14

Add the five-hour quota reset countdown to each standalone provider header without changing card dimensions. Keep both remaining percentages; display unavailable reset times as a dash. Localize durations and show exact reset dates in native hover help, including over the drag surface.

## 1.1.5 — 2026-10-14

Place slightly larger quotas beside the visible sprite edge with a two-point baseline gap. Above 50% remaining the pet happily types; at 15–50% it types slowly with drooping eyes and occasional yawns; below 15% it sleeps with slow breathing and drifting Zs. The lowest valid selected quota determines the state. Preserve shared scaling and Reduce Motion.

## 1.1.4 — 2026-10-14

Reduce the standalone mascot baseline by 10%, bring quota cards closer, and apply the size slider to the whole pet-and-quota composition. Both now retain the same relative scale at every size instead of quota cards reaching a separate growth cap.

## 1.1.3 — 2026-10-14

Keep standalone quota cards inside the pixel mascot’s vertical silhouette, including sleeping poses and smaller sizes. Remove Compact mode and migrate saved Compact preferences to Expanded.

## 1.1.2 — 2026-10-14

Move standalone pet quota badges to the right of the mascot, with Claude and Codex stacked vertically. Size the window around the horizontal layout while preserving full-surface dragging and selected-provider filtering.

## 1.1.1 — 2026-10-14

Remove the visible drag instruction. Add a full-width native title-bar drag surface and full-surface standalone pet dragging with its native context menu. Show readable Claude/Codex 5-hour and weekly remaining percentages below the standalone pixel pet, honoring selected services/windows, demo labels and unknown/stale data. Adapt pet-only window size to preserve readable badges.

## 1.1.0 — 2026-10-14

Switch to Concept C — Pixel Terminal Pet. Replace the mascot system with twelve original layered pixel characters and laptops, species-specific markings and sleeping poses. Add monospace terminal typography, stepped quota bars, restrained dark panels, terminal color palettes and a pixel capybara app icon. Retain native dragging, attached mascot, collapsible provider cards, selection and live integrations.

## 1.0.3 — 2026-10-14

Add independently collapsible Claude/Codex cards with accessible arrow controls and persisted open states. Add Both / Claude only / Codex only selection in Providers settings. Resize the widget downward from its existing top edge when details are opened; shrink it when closed or a provider is hidden. Preserve dragging and attached mascot behavior.

## 1.0.2 — 2026-10-14

Fix borderless SwiftUI dashboard dragging with a native AppKit drag surface in the header. Attach the mascot inside the dashboard by default so both move as one window; preserve independent pet mode as an explicit setting. Do not reorder windows while the mouse is dragging. Migrate the new attachment preference without resetting existing animal, language or appearance settings.

## 1.0.1 — 2026-10-14

Fix pinned panel eligibility across other applications, Stage Manager sets and fullscreen Spaces. Reassert floating levels and ordering on display/Space/application changes while respecting hidden windows and the unpinned preference. Add native window regression checks.

## 1.0.0 — 2026-10-14

Initial local build: independent native floating windows, twelve original vector companions, configurable appearance/moods, Codex app-server and Claude statusline adapters, quota dashboards, demo mode, menu bar recovery, local preferences, English/Turkish settings, native optional notifications, login item support, regression tests and universal release scripts. GitHub publishing, Developer ID signing and notarization are external configuration steps.
