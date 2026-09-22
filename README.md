# Calorie Tracker (iOS, SwiftUI)

A calorie and nutrition tracker. Log meals by photographing them (AI recognition), by scanning a
packaged food's barcode, or by searching a public food database. Daily logs, goals and saved foods
stay on the device.

- **Requirements:** Xcode 26, iOS 17+
- **Open:** `CalorieTracker.xcodeproj`, then Run. The project is generated from `project.yml` with
  [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`xcodegen generate`) after adding or removing files.

## Screens

| Screen | File |
|---|---|
| Sign in / Register | `Features/Auth/` |
| Onboarding (body stats → calorie goal) | `Features/Onboarding/` |
| Diary: calorie ring, macros, meals by day | `Features/Diary/DiaryView.swift` |
| Food database: barcode scan + search | `Features/FoodLookup/FoodLookupView.swift` |
| Product detail: portion picker, add to log | `Features/FoodLookup/ProductDetailView.swift` |
| Photo recognition | `Features/Camera/CameraFlowView.swift` |
| Progress, AI coach, profile | `Features/Progress/`, `Features/Coach/`, `Features/Profile/` |

## External API: Open Food Facts

[Open Food Facts](https://world.openfoodfacts.org) is a free, public REST API for packaged foods
(no key needed). The app calls it directly with `URLSession` and `async`/`await`:
`Networking/OpenFoodFactsAPI.swift`.

- `GET /api/v2/product/{barcode}.json` looks up a product by barcode.
- `GET search.openfoodfacts.org/search?q=` searches by name. Requests wait until typing pauses,
  and a new search cancels the previous one, because Open Food Facts rate-limits search.
- **Decoding:** Swift `Codable` in `Models/OpenFoodFactsDTOs.swift`. The data is crowd-sourced and
  the same field can come in different shapes, so the decoder handles them:
  - `brands` can be a string or an array.
  - Numbers sometimes arrive as strings.
  - Some products give energy only in kJ; those values are converted to kcal.
  - Missing fields don't break decoding.
- **Error handling:** errors are typed as `OFFError`:
  - invalid barcode
  - not found
  - no nutrition data
  - rate limited (HTTP 429)
  - offline
  - server error
  - decoding error

  Each one has its own message in Chinese and English, and search failures offer a Retry button.
- **Tests:** `CalorieTrackerTests/OpenFoodFactsDecodingTests.swift` covers each of these cases.

The app also talks to the project's own backend (`Networking/APIClient.swift`): sign-in,
syncing logs across devices, and AI photo recognition.

## Data persistence

| Data | Stored with | File |
|---|---|---|
| Profile, daily logs, meals | SwiftData | `Persistence/ProfileRecord.swift`, `DayLogRecord.swift` |
| Viewed and favorite products (also an offline cache) | SwiftData | `Persistence/SavedProductRecord.swift` |
| Language preference | UserDefaults | `Localization/LocalizationStore.swift` |
| Login token | Keychain | `Networking/KeychainStore.swift` |

Logs are written locally first and synced to the server in the background, so they are there after
the app is force-quit and reopened, even with no network. A product that was viewed before still
opens offline.

## UI & motion

- The calorie ring and macro bars fill in when the screen appears, then spring to new values.
- Numbers roll to new values instead of jumping.
- The selected day in the week strip glides between days (`matchedGeometryEffect`).
- Meal rows slide in when added and out when deleted.
- A scan-line animation plays over the photo while the AI analyzes it.
- Search shows placeholder rows that shimmer while results load, and results slide in one after
  another.
- Cards shrink slightly while pressed.
- Tapping favorite bounces the heart icon.
- Haptic feedback confirms saves, selections and errors.

Shared helpers are in `Shared/Motion.swift`.
