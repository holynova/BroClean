# BroClean

<!-- impeccable:product-schema 1 -->

## Platform

macOS

## Stack

Existing Swift 6, SwiftUI and AppKit menu bar application, macOS 14+.

## Users

People inspecting browsers left running by AI tools and automated tests on their own Mac.

## Product Purpose

Identify browser instances and their likely launch sources, inspect resources, protect ongoing work, and explicitly close selected instances.

## Capabilities and Constraints

User confirmed on 2026-11-16: retain the native menu bar form and existing discovery/termination core; rewrite the interface and improve source recognition, instance protection and bulk-close workflow. English UI is the existing product convention. Current user requests a simpler, restrained redesign and several icon candidates for selection.

Keep filters, sorting, individual close, explicit force quit, persistent protection shared with CLI, source evidence, estimated memory, unknown page counts, login settings and GitHub entry. Never terminate real user processes during validation. Demo operations are simulated. No automatic cleanup or deletion of browser data.

## Evidence on Hand

Sources/BrowserScopeApp/App.swift, BrowserScopeCore, Tests, docs/PRODUCT-SPEC.md, and design/approved-ui.png (historical concept; current source differs). Repository source is entirely untracked at intake; build and inspect a staging copy before syncing reviewed changes.

## Brand Commitments

BroClean. Restrained interface. App icon A (stacked windows) approved on 2026-11-16.

## Product Principles

- Show the source and current state before an action.
- Represent uncertainty visibly; unknown values are not zero.
- Keep consequential operations scoped, explicit and reviewable.
- Use native Mac controls and keyboard access.

## Confirmed design direction — 2026-11-16

The user chose scheme 2 (grouped list), the restrained blue accent and its tonal variants, monochrome source application icons, and a close control per group. Group actions review a frozen visible group, skip protected items, and require confirmation; personal-browser closure warns about active work. Prototype actions remain simulated. App icon A (stacked windows) was subsequently approved for release 0.3.0.
