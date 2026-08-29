# Client-side Gemini API key

CatCare calls Google's Gemini `generateContent` API **directly from the
device** — there is no intermediary backend or Cloud Function. The API key
is bundled into the app at build time and read at runtime. This document
explains how the key is shipped, where the rate-limit lives, and what to do
if it leaks.

## Where the key lives

| Surface                  | Location                                                   |
| ------------------------ | ---------------------------------------------------------- |
| Source of truth          | `assets/.env` (`GEMINI_API_KEY=…`)                         |
| Build-time override      | `--dart-define=GEMINI_API_KEY=…` (used by CI / release)    |
| Runtime accessor         | `AppEnv.geminiApiKey` in `lib/core/constants/app_env.dart` |
| Build asset entry        | `pubspec.yaml` → `flutter.assets/.env`                     |
| Where it goes on-device  | Inlined into the Flutter snapshot inside the AAB / IPA     |

`AppEnv.geminiApiKey` prefers `--dart-define` so CI can rotate the key
without touching the repo, and falls back to `dotenv.env['GEMINI_API_KEY']`
for local runs.

## Restrictions you MUST apply in AI Studio

The key ships in a public binary, so it is **not a secret** — treat it as
a "revocable project token". Limit the blast radius in Google AI Studio
before you ship:

1. **Restrict the API.** Open the key in AI Studio → *API restrictions* →
   set to **Restrict to: Generative Language API only**. This stops the
   key from being abused against other Google APIs (Drive, Maps, etc.).
2. **Restrict by app / package name.** Add the Android package id
   (`com.example.cat_care` or your release id) and iOS bundle id as
   allowed referrers where supported.
3. **Restrict by HTTP referrer (web) or IP (mobile is best-effort).**
   Mobile apps cannot send a real referrer, so this is mainly belt and
   suspenders.
4. **Set a per-minute quota.** Generative Language API allows a small
   per-minute request cap on free tier and a project-level QPM on paid
   tier. Pick something just above your worst-day forecast so the app
   still works for legitimate users.
5. **Enable quota alerts.** Email notifications for runaway usage.

## On-device rate limit

Even with the project-wide cap, a single device could burn through the
free tier in a few days. We add a second, **per-device** guard so a
single user can't starve other users:

| Feature        | Daily cap (UTC) | Counter pref key        | Date pref key          |
| -------------- | --------------- | ----------------------- | ---------------------- |
| Chat           | 20              | `ai.local.calls.chat`   | `ai.local.date.chat`   |
| Weekly report  | 5               | `ai.local.calls.weekly` | `ai.local.date.weekly` |
| Food label     | 5               | `ai.local.calls.food`   | `ai.local.date.food`   |

- Caps are reset at **00:00 UTC**. The reset is computed lazily — the
  first request after UTC midnight rolls over to the new day's counter.
- Counters live in `SharedPreferences` (key `ai.local.*`). Uninstalling
  the app or "Clear data" wipes them, but the user gets the day's cap
  back in exchange — this is intentional and documented in the
  in-app banner.
- The cap is **enforced client-side**. A determined user with the AAB
  can disable it, but the goal is to be a polite neighbour on the
  shared free tier, not to enforce a security boundary.
- When a cap is hit, the repository throws `AiQuotaExceededFailure`.
  `AiProvider` flips `aiAvailable` to `false`, every input in the
  affected screen is disabled, and `AiQuotaBanner` explains the reset
  time.

Caps are configurable for tests via `RateLimitBuckets(limits: …)`;
production defaults are exported as `RateLimitBuckets.defaults`.

## Leak response

If you suspect the key has been scraped from the binary:

1. **Revoke immediately.** In AI Studio → *API keys* → click the key →
   *Revoke*. This kills the leaked credential within seconds; AI Studio
   propagates the revocation to the Generative Language API gateway.
2. **Generate a fresh key** with the same restrictions (see above).
3. **Push a hotfix release** that builds with the new key via
   `--dart-define=GEMINI_API_KEY=…` in your CI pipeline. Make sure CI
   is using a **secret store** (GitHub Actions secrets, GitLab masked
   variables, etc.) — never commit the new key to `assets/.env` in the
   repo.
4. **Audit usage.** AI Studio → *Metrics* for the project shows RPM /
   TPM per day. A leaked key typically shows a flat-rate spike from
   unfamiliar ASNs or geographies within hours of release.
5. **Update `.env` only after the release is shipped.** The repo's
   `.env` is the local-dev key — keep it as `replace_me` (or rotate it
   to a fresh restricted dev key) so a `git clone` doesn't ship a
   working credential.

## Accepted trade-offs

This design trades API-key confidentiality for **simplicity** — no
backend to deploy, no auth tokens to refresh, no second point of
failure. It is appropriate because:

- The key is restricted to the Generative Language API and capped at
  the project level, so even a fully compromised key cannot cost more
  than the project-wide monthly budget.
- Theon-device cap means a single abusive user can only consume their
  own daily allotment, not the whole quota.
- There is no PII, no customer authentication, and no payment
  authority behind this key — only LLM completions.

If a future feature needs to call a more sensitive Google API, that
call **must** go through a backend that holds the secret server-side.