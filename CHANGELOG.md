# Changelog

All notable user-facing changes to List Tracker are documented here.

## [Unreleased]

- CSV exports now protect spreadsheet-formula-looking values while preserving
  safe export/edit/import round trips and the readable four-column format.
- Android release builds now require a private production signing configuration
  instead of falling back to the debug key.
- Public distribution remains blocked until a signed artifact, security-alert
  review, and fresh-install/upgrade verification are recorded.

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
