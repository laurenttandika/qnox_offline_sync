# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2025-08-20
### Added
- Initial release of **qnox_offline_sync**.
- Offline-first sync engine (`QnoxSync`) with:
  - Cache-first GET support.
  - Durable offline mutation queue (POST/PUT/PATCH/DELETE).
  - Automatic background/foreground sync with exponential backoff.
  - Pluggable conflict resolution strategies: client-wins, server-wins, merge (with custom resolver).
- Authentication hooks:
  - `authTokenProvider` for Bearer token injection.
  - `refreshToken` for handling 401 responses and retrying once with a fresh token.
- Storage abstraction `QnoxLocalStore` for custom backends (Drift, Isar, Hive, etc.).
- Example app demonstrating GET (cache) and POST (queue if offline).
- Platform interface and method channel stubs for Android/iOS with `getPlatformVersion`.

