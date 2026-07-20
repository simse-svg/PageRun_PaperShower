# Reading Pace App

Strava-style reading timer app built with Flutter.

## Features

- 2 tabs: `Home`, `Record`
- `Record` tab
  - Enter start page
  - Start timer
  - Stop timer and enter end page
  - Automatically calculates pace (`pages/min`)
- `Home` tab
  - Shows saved reading records as posts/cards
  - Includes pages, duration, and pace

## Run

```bash
flutter pub get
flutter run
```

## Optional Crash Reporting

This app is configured for minimal collection only.

- Default: sends nothing
- If `SENTRY_DSN` is provided at build/run time: sends crash reports only
- No usage analytics, no session replay, no performance tracing, no default PII

Example:

```bash
flutter run --dart-define=SENTRY_DSN=your_dsn_here
```

## Core Rule

- Pace formula: `pace = pagesRead / minutesElapsed`
