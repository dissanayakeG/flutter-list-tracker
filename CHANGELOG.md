# Changelog

All notable user-facing changes to List Tracker are documented here.

## [Unreleased]

- Added a local Vocabulary feature with language-scoped categories, optional
  subcategories, dictionary views, completion/edit controls, and quoted batch
  entry of word/meaning pairs.
- Added Lists, Languages, and Settings bottom navigation. List CSV transfer
  and List-category management now live in Settings.
- CSV exports now protect spreadsheet-formula-looking values while preserving
  safe export/edit/import round trips and the readable four-column format.
- Local Android release-mode smoke builds are debug-signed. They are not
  distribution artifacts; protected production signing and device verification
  are scheduled for Phase 14.

## [0.1.0] - 2026-09-05

Initial feature-complete local release candidate, including:

- Category and List management with edit and delete flows.
- List Entries with optional dates, edit, and delete support.
- Light, Dark, and System theme selection.
- Human-readable CSV export and validated CSV import.
- Category-scoped import resolution with duplicate and ambiguity protection.
- Local SQLite persistence with schema-v3 UUID identities.
- Responsive Material 3 UI and accessibility-focused states.

This release is local-first. Google Drive backup and synchronization are not
included yet.
