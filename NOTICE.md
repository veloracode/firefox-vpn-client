# Notices and change marking (AGPL-3.0)

This program is free software under the **GNU Affero General Public
License v3.0** (see `LICENSE`). It is a modified version of the
armanlife Firefox VPN client (`armanlife/arman-vpn-client`, upstream
v1.0.19), a client for Mozilla's Firefox VPN / Mozilla VPN service.
Mozilla, Firefox, and their logos are trademarks of the Mozilla
Foundation; this is an unofficial client, as its About page states.

## What changed in this release (the "Zed rebuild")

- The entire user interface was rebuilt from scratch on a Dart
  reimplementation of the **ZedSecure v3.2.0 design system** (four
  designs — Bento, Pixel, Old, Glass — Liquid Glass, the central motion
  system, and the per-design settings model), studied from ZedSecure
  by CluvexStudio, itself AGPL-3.0 software. The design parameters are
  documented behaviour and geometry, re-expressed in Flutter/Dart; the
  interface code under `app/lib/ui/zed/` and the screens it drives are
  new code written for this project.
- The previous interface designs (Foxy/Classic homes and the earlier
  Pixel/Portal/Old home ports) were removed as routed pages.
- **The connection core did not change**: `core/` (Go) and
  `app/lib/core/` are byte-identical to the previous release
  (v1.0.1+252); the SHA-256 manifest in `AUDIT.md` proves it.
- Made by arblant & Muse.

Source for this release is published with the release itself, as
AGPL-3.0 requires.
