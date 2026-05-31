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

## Core Rule

- Pace formula: `pace = pagesRead / minutesElapsed`
