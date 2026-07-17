# Changelog

---

## v0.6.0 — Event Sync, Pickers & UI Polish

### Features

#### Treatments & Events

* Synced calendar events with pills, treatments, and notes
* Reworked the treatments UI/UX
* Split pill listing from pill creation and smoothed draggable-sheet interactions
* Animated the pill sheet and moved deletion into a confirmation dialog
* Animated pill status updates after toggling
* Announced the new treatment category with an info panel
* Added a drag handle to the calendar

#### Health & Tracking

* Split health recommendations into active and dismissed sections
* Added pill details to the vet card

#### AI Assistant

* Send full pet context to the AI assistant

#### Registration & Profiles

* Reused profile widgets in the registration summary and added optional data cards
* Added permanent profile deletion

#### Notes & Diary

* Split entry creation from listing for diaries and notes

#### Documents

* Separated file history from file upload

#### UI & UX

* Added pinned headers to the home, health, and events pages
* Replaced action bubbles with iOS-style capsules
* Added a custom animated picker for dose unit and reminder variant
* Added an animated picker to event creation
* Unified input field styling
* Added a refined count badge

### Improvements

* Gated not-yet-ready features (AI advice, biometrics, export, help, rate us) behind flags
* Gated cloud sync and profile city behind release feature flags
* Replaced the custom date spinner with the native Cupertino picker
* Improved event usability and source-based captions
* Refactored pill taking and event synchronization
* Hid empty fields on the vet card
* Introduced a custom switch widget
* Improved text styles across the app
* Standardized font sizes and constraints
* Refined text color usage and added missing fonts
* Bundled the Rubik font
* UI becomes more adaptive to small screens

### Fixes

* Fixed treatment duplication
* Fixed overdue logic and used the parent color for synced events
* Improved pill-taking reliability
* Fixed a race condition when completing pills and pill events
* Fixed endless pill notifications
* Added validation and a weight limit to pill creation
* Included repeating events
* Used the "remind before" variant in the event view
* Improved cloud sync (upsert instead of wipe, remove stale entities)
* Synced files and chats for authenticated users
* Fixed profile sync after delete, switch, and create
* Fixed syncing of custom breeds
* Fixed the client sending the wrong timezone
* Fixed a null path when exporting all profiles
* Fixed pop scope blocking profile deletion
* Fixed notification ID collisions
* Sent quiet notifications (no sound or haptics) instead of skipping them
* Reduced save frequency while streaming AI responses
* Sent a properly encoded message array to the AI
* Added crash-reporting opt-out and anonymized reports
* Protected stored files
* Fixed pet and pill serialization
* Fixed gender and mood entry serialization
* Handled pets with an empty breed
* Polished the final onboarding step
* Hid "restore from server" when already authenticated during onboarding
* Hid the logout action when unauthorized
* Fixed the title layout in draggable sheets
* Refreshed the home page after opening the note sheet
* Fixed avatar background showing transparent instead of white
* Adjusted date picker limits
* Shrank the notification icon and improved event-saving stability

---

## v0.5.1 — Avatar preview, context actions

## v0.5.0 — Food Diary, History Insights & Sync Polish

### Features

#### Food Diary

* Added different meal types to the food diary
* Made diary sheets UI consistent

#### History & Charts

* Added filter options to pet history
* Added mood history chart
* Improved weight chart UI
* Group entries by date and sort mood and food entries by day-part
* Show last entry mood icon in the mood history widget

#### Treatments & Events

* Added doses and multiple take entries for on-demand pills
* Added dedicated logic for all-day events

#### Cloud Sync & Accounts

* Completed cloud synchronization implementation
* Replaced manual sync buttons with a toggle and clearer status value
* Added profile context menu

#### AI Assistant

* Added auth gate for the AI assistant
* Added AI-generated badge

#### Privacy & Settings

* Added terms of use and privacy policy to settings
* Added privacy and terms acceptance to the auth/registration page
* Sync app version in settings

#### Notifications

* Improved notifications: verbose descriptions, fallbacks, and auto-generation on start
* Added notification channels

### Improvements

* Switched profile storage from shared preferences to secure storage
* Save profile immediately after change
* Added custom species option and refined the custom breed button
* Reused shared widgets for file and gender pickers
* Improved history sheets UI
* Disabled crash reporting by default

### Fixes

* Fixed draggable sheets expanding infinitely
* Fixed event tile not updating after a date change
* Fixed clearing a profile not triggering logout
* Fixed AI page messages overflowing the header
* Fixed weight entries not sorting by date
* Fixed shadowed params not clearing after creating a food entry
* Fixed theme color initialization based on pet color
* Fixed 'made by AI' badge UI
* Removed the first-date interval requirement for pill creation
* Removed red highlight for treatments
* Restored transparent glass plates

---

## v0.4.1 — Switch to Impeller renderer

## v0.4.0 — AI Assistant, Cloud Sync & User Accounts

### Features

#### AI Assistant

* AI assistant can now create reminders and events automatically
* Added AI-generated event suggestions
* One-tap creation of suggested events
* Added hold-to-talk voice interaction
* Refactored AI chat architecture

#### Cloud Synchronization

* Added cloud account support
* Added cloud synchronization between devices
* Improved synchronization reliability and data consistency

#### User Accounts

* Added user profiles
* Added account management infrastructure
* Unified user and pet profile components
* Improved profile switching experience

#### Treatments & Events

* Added support for on-demand medications
* Added custom colors for treatments
* Added custom icons for events and treatments
* Improved treatment-to-event synchronization
* Improved event creation workflows

#### UI & UX

* Added skeleton loading states
* Improved page transition performance
* Redesigned AI chat page
* Improved navigation consistency
* Added healthy pet status animations
* Added reusable pressable interaction components

### Improvements

* Improved application architecture and page organization
* Improved draggable sheet system
* Updated project documentation

### Fixes

* Fixed AI chatbot reliability issues
* Fixed synchronization issues between events and treatments
* Fixed health page refresh behavior
* Fixed various UI inconsistencies

---

## v0.3.4 — LocalNotification hotfix

* Suppress shrinking for com.google.gson to avoid RuntimeException "Missing type parameter"

---

## v0.3.3 — Treatment System & Major UI Refresh

### Features

#### Treatments & Medication

* Added pill reminder system
* Support for multiple medication takes per day
* Improved treatment scheduling logic
* Automatic synchronization between treatment history and health page
* Support for uncompletable events
* Treatment category preselection when opening treatment details

#### Events

* Redesigned events page
* Redesigned event draggable sheet
* Unified event type handling
* Improved overdue event visualization
* Improved event search
* Improved event creation flow from notes
* Unified draggable sheet system across the app

#### Registration & Profiles

* Redesigned pet registration flow
* Redesigned profile page
* Redesigned settings page
* Added species support
* Improved profile switching UX

#### UI & UX

* Added skeleton loading animations
* Reduced lag during page transitions
* Added GlassTileList widget
* Unified draggable sheet styling
* Redesigned AI chat page
* Improved navigation bar
* Added new color palette
* Improved overall UI consistency and responsiveness

### Improvements

* Improved synchronization reliability across services
* Improved event preview offsets and warnings
* Optimized widget hierarchy and removed unnecessary widgets
* Temporary cache disabling for debugging and synchronization fixes

### Fixes

* Fixed font colors on events page
* Fixed synchronization issues on health page
* Fixed several UI inconsistencies
* Disabled notifications on unsupported debug platforms

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