# Aurora Task — Random Image Viewer

Single‑screen Flutter app that fetches a random image from the provided API and displays it centered as a square. The background color adapts to the image’s palette for an immersive effect. A button labeled “Another” fetches a new image with smooth transitions and basic accessibility.

## Features
- Square, centered image with rounded corners
- Background color adapts to the image (dominant/muted/vibrant)
- “Another” button to fetch a new image
- Smooth transitions (image fade‑in, animated background)
- Loading placeholders and graceful error handling
- Light/Dark mode support
- Basic accessibility (semantics, tooltips, disabled states)

## Tech Choices
- Networking: `dio`
- Image loading & caching: `cached_network_image`
- Palette extraction: `palette_generator`
- Architecture: MVC (Model, View, Controller + Service)

## API
- Base URL: `https://november7-730026606190.europe-west1.run.app`
- Endpoint: `GET /image`
- Example response:
  ```json
  { "url": "https://images.unsplash.com/photo-1506744038136-46273834b3fb" }
  ```

## Project Structure (Relevant)
- `lib/models/random_image.dart` — Model representing the API payload
- `lib/services/random_image_service.dart` — Dio service hitting `/image`
- `lib/controllers/random_image_controller.dart` — Orchestrates fetch, state, palette extraction
- `lib/views/random_image_page.dart` — UI (square image, button, loading/error, animations)
- `lib/app/app.dart` — MaterialApp setup (themes, home)
- `lib/main.dart` — App entry point

## Run
1. Install Flutter and set up devices/simulators.
2. Fetch deps:
   ```bash
   flutter pub get
   ```
3. Run:
   ```bash
   flutter run
   ```

## Test
```bash
flutter test
```
Included: a simple widget test verifying the “Another” button appears without triggering a real network call.

## Notes
- CORS is enabled server‑side (relevant for web).
- Unsplash image URLs can be large; `cached_network_image` provides disk/memory caching and placeholders.
- `palette_generator` is used for dominant color extraction; consider alternatives if long‑term support is required.

---

## Work Summary
- Added dependencies in `pubspec.yaml`: `dio`, `cached_network_image`, `palette_generator`.
- Implemented MVC:
  - Model: `RandomImage` (validates presence of `url`).
  - Service: `RandomImageService` (Dio `GET /image`).
  - Controller: `RandomImageController` (loading/error state, palette extraction, notify listeners).
  - View: `RandomImagePage` (square image, adaptive background, fade‑in, loading overlay, error placeholder, “Another” button).
- App shell:
  - `AuroraApp` with Material 3 themes (light/dark), home set to `RandomImagePage`.
  - `main.dart` simplified to run `AuroraApp`.
- Polish:
  - Animated background transitions, adaptive progress indicators, semantics/tooltip, responsive square sizing.
  - Replaced deprecated `withOpacity` with `withValues` to satisfy lints.
- Testing:
  - Updated `test/widget_test.dart` to load the page without network (`autoLoad: false`) and assert “Another” button presence.
