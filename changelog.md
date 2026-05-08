# Changelog

---

## v0.3.2 — Appearance System & UI Refinement

### Features
- Introduced appearance controller for centralized theme management
- Added support for soft badges across UI
- Added theme controller and dynamic color handling

### Improvements
- Updated home page layout and color system
- Improved input transparency and visual hierarchy
- Moved health card to a higher priority position on home screen
- Added gradient styling for health components

### Refactoring
- Removed magic numbers across codebase
- Optimized event filtering logic
- General UI consistency improvements

---

## v0.3.1 — Health, Documents & Interaction Improvements

### Features

#### Health & Tracking
- Food tracking system (meal time, appetite score, weight in grams)
- Appetite stepper with visual indicators
- Health scoring system (OK / Warning / Critical states)
- Smart health analysis:
  - Weight trend detection
  - Appetite anomaly detection
  - Overdue vaccinations and events tracking

#### Notes & Diary
- Symptom-based notes system with predefined tags
- Voice input improvements
- Notes history with delete support

#### Documents
- File storage system with categories (vaccination, insurance, etc.)
- File upload (camera or file picker)
- Document history with preview and system viewer integration

#### Treatments
- Treatment tracking (vaccinations, parasites, etc.)
- Automatic event creation for next treatments
- Reminder system for upcoming treatments

#### UI & Interaction
- Swipeable event cards (edit/delete actions)
- Smart date formatting (today, tomorrow, etc.)
- Vet information card
- Improved health summary UI with actionable badges

### Improvements
- Performance optimization (removed heavy blur effects)
- Repaint isolation for UI components
- Improved charts (axes, labels, scaling)
- Better handling of duplicate entries (weight, mood, food)

### Fixes
- Event completion state update reliability
- Profile color application issues
- Layout issues (navbar overflow, event preview offsets)
- Various UI inconsistencies

---

## v0.3.0 — Event System Overhaul & Multi-Pet UX

### Features
- Per-occurrence event completion tracking
- Multi-pet event linking
- "All pets" calendar mode
- Overdue event highlighting and prioritization
- Pet badges in event cards

### Improvements
- Migration to new event storage model (`pet_events_v2`)
- Improved profile switching UX

---

## v0.2.0 — Events Redesign & Expanded Functionality

### Features
- Event completion tracking
- Custom repeat rules (weekday selection)
- New event categories (walk, training, vaccination, other)
- Correct rendering of recurring events in calendar

### UI
- Glass-style redesign of event sheets

---

## v0.1.5 — Multi-Profile Support

### Features
- Multiple pet profiles
- Profile switching
- Profile color support

### UX
- Redesigned registration flow

---

## v0.1.4 — AI & Health Tracking

### Features
- AI chat integration
- Mood tracking
- Weight tracking

### Improvements
- Health service improvements
- Profile page updates

---

## v0.1.3 — Activity & Notifications

### Features
- Activity indicators
- Notification system

---

## v0.1.2 — Events & Calendar Foundation

### Features
- Event creation and management
- Event categories
- Calendar integration

---

## v0.1.1 — Profiles & Core Architecture

### Features
- Pet profiles and registration
- Profile images

### Architecture
- Introduced ProfileService
- Modular page structure

---

## v0.1.0 — Initial Feature Set

### Features
- Home screen
- Basic calendar
- AI chat (early version)

---

## v0.0.x — Early Development

### Features
- Draggable sheets
- Custom UI components
- Settings page
- Unified theme

### Improvements
- Infrastructure setup (Android, iOS, CI/CD)
- Bug fixes and refactoring

---

## v0.0.1 — Initial Commit

- Project initialization