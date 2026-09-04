# CatCare BD

CatCare BD is a Flutter companion app for cat owners in Bangladesh. It keeps each cat's routines, nutrition, health history, and care guidance in one place, with optional AI-powered insights that support—not replace—professional veterinary care.

## What it includes

- Multiple cat profiles, including photos and individual care histories
- A daily dashboard for routines, food and water goals, upcoming care, and insights
- Custom care routines for feeding, water, medicine, play, grooming, litter, and more
- Local reminders for routine tasks, medications, and vaccinations
- Meal and water logging with per-cat nutrition targets and reports
- Health records, medications, vaccinations, deworming, weight trends, and behavior tracking
- Vet finder, emergency guidance, cat-care guides, and English/Bangla FAQs
- AI chat, weekly summaries, and food-label extraction, with per-device usage limits
- Firebase-backed authentication and data storage, including Google sign-in

## Tech stack

- Flutter and Material 3
- Provider for state management and `go_router` for navigation
- Firebase Authentication, Cloud Firestore, Cloud Storage, and Messaging
- Local notifications, Google Maps, and location services
- Gemini Generative Language API for optional AI features

## Getting started

1. Clone the repository and open the project directory.
2. Install packages:

   ```bash
   flutter pub get
   ```

3. Create your local environment file:

   ```powershell
   Copy-Item .env.example .env
   ```

4. Configure Firebase for your own project when required:

   ```bash
   flutterfire configure
   ```

   This updates the platform configuration used by `lib/firebase_options.dart`. The committed Firebase configuration identifies a project but is not a replacement for configuring the project and its security rules for your deployment.

5. Add a restricted `GEMINI_API_KEY` to `.env` to enable AI features. You can also supply release values using Dart defines, for example:

   ```bash
   flutter run --dart-define=FLAVOR=dev --dart-define=GEMINI_API_KEY=your_key
   ```

6. Run the app:

   ```bash
   flutter run
   ```

In debug builds, the UI can still open when Firebase is not configured; sign-in and cloud-backed functionality require a working Firebase setup.


## Testing and checks

Run the automated test suite with:

```bash
flutter test
```

The repository also includes architecture and native-plugin compatibility checks in `tools/`.

## Project structure

```text
lib/
  core/             Shared models, services, theme, constants, and widgets
  content/          Seeded care content and content models
  features/         Feature-first modules: authentication, cats, routine,
                     nutrition, health, notifications, AI, vet finder, and more
  routes/           Route definitions and router configuration
  main.dart         App bootstrap and provider wiring
assets/             Fonts, FAQs, prompts, and image assets
docs/               Product, design, architecture, and key-handling documents
landing_page/       Static promotional website and Android download
```

## Landing page

The companion marketing site is in [`landing_page/`](landing_page/). Open `landing_page/index.html` in a browser or host that directory as static files.
