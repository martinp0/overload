# Shipping Overload on Samsung

Overload stays a static web app. Samsung Galaxy phones get that same app inside a Capacitor Android shell, with fold-aware layouts. A 2022 Samsung TV gets a separate follow-along package under `tizen/` that reuses the generator and the lifting log.

This file is the runbook. Nothing here publishes the app. You sign it, host the privacy policy, and submit it yourself.

## Why Capacitor, not a TWA

A Trusted Web Activity (Bubblewrap) is a Chrome window around a hosted site. It needs a stable HTTPS origin and a Digital Asset Links file before Android will treat it as a real app. This repo has no production URL, and the log is meant to work in a gym with no signal. A TWA’s first launch has to download the site.

Capacitor packages the same HTML, CSS, and JS into the APK. The first open is offline. Fold posture comes from AndroidX WindowManager (`FoldingFeature`), which is the API Samsung documents for Flex Mode, and is pushed into the page. Chrome’s Device Posture and Viewport Segments APIs are still honored when they exist, including in a browser or an installed PWA. The shell does not replace those.

A TWA is still a reasonable later step once the site has a permanent address. The manifest is already a standalone PWA (`orientation: any`, so a Fold can rotate). Don’t add a second Android project until that origin exists.

`applicationId` is `cz.martinpohl.overload`, the same id as the iPhone app. Don’t change it after the first upload.

## What you still have to provide

- A Samsung account with a [Galaxy Store Seller Portal](https://seller.samsungapps.com) seller profile (country: Czech Republic).
- A Google Play Console account if you also want Play. Google’s registration fee is separate from Samsung.
- A release keystore that never enters git. Commands are below.
- A public `https://` URL for `privacy.html`. GitHub Pages is enough: `https://<user>.github.io/<repo>/privacy.html`.
- The contact email you want on the store listing. The privacy page tells people to use that address. It does not invent one.
- Store screenshots at the portal’s pixel sizes. The PNGs in `samsung/screenshots/` prove the layouts; they are not 1440×3120 store assets. Recapture on a phone, or export from the sizes in the screenshot plan.
- For the TV: Developer Mode on the The Serif, and one `aerotizen certs` sign-in. The TV package is sideloaded, not submitted to the TV seller office.

## Android build

Requirements: Node 22, JDK 21, Android SDK 36 (Capacitor 8).

```sh
npm ci
npm test
npm run android:debug
```

Debug APK:

```text
android/app/build/outputs/apk/debug/app-debug.apk
```

Install it with `adb install -r` on that path. Debug builds allow WebView inspection from `chrome://inspect`. Release builds do not.

The Gradle file reads `android/version.properties` (`VERSION_CODE`, `VERSION_NAME`). Override either with `ANDROID_VERSION_CODE` and `ANDROID_VERSION_NAME`. Every store upload needs a higher `versionCode`.

### Signing

Create the keystore outside the repo. `*.jks` and `*.keystore` are gitignored. Do not commit the passwords.

```sh
mkdir -p "$HOME/keystores"
keytool -genkeypair -v \
  -keystore "$HOME/keystores/overload-release.jks" \
  -alias overload \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=Martin Pohl, O=Martin Pohl, L=Prague, C=CZ"
```

Then:

```sh
export ANDROID_KEYSTORE_PATH="$HOME/keystores/overload-release.jks"
export ANDROID_KEYSTORE_PASSWORD="…"
export ANDROID_KEY_ALIAS="overload"
export ANDROID_KEY_PASSWORD="…"
export ANDROID_VERSION_CODE=1
export ANDROID_VERSION_NAME=1.0.0
npm run android:release
```

Signed app bundle:

```text
android/app/build/outputs/bundle/release/app-release.aab
```

If those four keystore variables are unset, `bundleRelease` still builds an **unsigned** AAB. That is what CI produces. Don’t upload the unsigned file. Play App Signing wants the AAB signed with your upload key; Google holds the app signing key. Use the same upload keystore for the Galaxy Store unless Samsung’s portal tells you to enroll in their signing separately.

Back up the keystore and both passwords. A lost upload key is a support ticket with Google and a new app id on Samsung if you cannot prove ownership.

## Galaxy Store Seller Portal

Do this yourself at [seller.samsungapps.com](https://seller.samsungapps.com). Confirm fees and the current target-API rule in the portal on the day you submit. Capacitor 8 targets API 36.

1. Sign in with the Samsung account and complete seller registration as a private developer in the Czech Republic. Have a government id ready. Free apps have not required the commercial seller agreement; paid apps do.
2. Create an application. Platform: Android. Default language: English (United States). Add Czech (`cs`) as a second language.
3. App name: `Overload`. Package name must match the binary: `cz.martinpohl.overload`.
4. Category: Health / Fitness. This is not a medical device and not a children’s app. In the age questionnaire, answer that it is not directed at children.
5. Upload the **signed** `.aab`. If the portal still asks for an APK, build `assembleRelease` with the same env vars (`android/app/build/outputs/apk/release/`).
6. Paste the English and Czech listing text below. Short description in the short field, the rest in the full description.
7. Icon: `icons/icon-512.png` (512×512 PNG).
8. Privacy policy URL: the public `privacy.html` address. The in-app Settings screen links to the same page.
9. Countries: Czech Republic, plus anywhere else you want. Content rating: complete the questionnaire. There is no account, no chat, no ads, no user-generated public content.
10. Screenshots: phone group, and the tablet group for the Fold inner display. See the plan below.
11. Save the draft. Submit for review only when you mean to. Review is Samsung’s, not something this repo can do.

Binary checklist Samsung and Play both tend to enforce: 64-bit (`arm64-v8a` is in the Capacitor build), a recent target SDK, a privacy policy URL, and an increasing `versionCode`.

## Google Play

Same signed AAB. [Play Console](https://play.google.com/console).

1. Create the app. Default language English. Add Czech (`cs-CZ`). App name `Overload`. Free. Not designed for children.
2. App integrity: enroll in Play App Signing. Upload the AAB signed with the keystore above. That keystore is the upload key.
3. Data safety: data is **not collected** and **not shared**. Workouts, templates, and settings stay in the app’s local storage on the device. There is no account and no server. The backup export is a file the user creates on purpose.
4. Privacy policy URL: the same public `privacy.html`.
5. Content rating (IARC): fitness / exercise reference, no violence, no social, no unrestricted web. Not a news or dating app.
6. Store listing: the text below. Phone screenshots required. Add a 7-inch or 10-inch tablet set so the Fold inner display has artwork. Feature graphic 1024×500 if the console asks.
7. Put the first build on an internal testing track. Promote to production when you want it public.

`INTERNET` is in the manifest because the WebView can load the UI fonts when the phone is online, and because Capacitor’s local server is still an Android WebView. Workouts are not uploaded.

## Listing text

### English

**Title:** Overload

**Short description:** Generate a lifting workout and log every set. Rest timer, progression hints, history. Data stays on the device.

**Full description:**

Overload builds a lifting session from the time you have, the muscles you want, and the equipment in front of you. Smart mode rotates push, pull, and legs from what has recovered since the last session.

Log every set. Each row shows what you lifted last time. Tick a set and the rest timer starts. When you hit the top of your rep range, the app suggests the next weight. You decide whether to take it.

History keeps every workout, with volume and new records. Save a session as a template and start it again with one tap. About 140 exercises are built in. Add your own.

Your log stays on the phone. There is no account. Export a backup from Settings when you want a copy.

On a Galaxy Z Flip, half-fold the phone during a set: the exercise and the rest timer stay on the top half, and the set buttons sit on the bottom half, within reach. On a Galaxy Z Fold, the open screen uses two panes, and a half-open Fold keeps the hinge clear. The cover screen of a Flip shows the rest timer when the app is allowed to stay open there.

**What’s new:** First Galaxy release. Phone, Z Flip, and Z Fold layouts.

### Czech

**Název:** Overload

**Krátký popis:** Vygeneruj silový trénink a zapisuj každou sérii. Časovač pauzy, postupné zvyšování zátěže, historie. Data zůstávají v zařízení.

**Plný popis:**

Overload sestaví trénink podle času, svalů a vybavení, které máš. Chytrý režim střídá tlak, tah a nohy podle toho, co se od minula stihlo zotavit.

Zapisuj každou sérii. Řádek ukáže, co jsi zvedl posledně. Zaškrtni sérii a spustí se časovač pauzy. Když se na všech sériích trefíš na horní hranici opakování, aplikace navrhne těžší váhu. Jestli ji přijmeš, je na tobě.

Historie drží každý trénink, objem a nové rekordy. Trénink si uložíš a příště ho spustíš jedním klepnutím. V knihovně je asi 140 cviků a můžeš přidat vlastní.

Deník zůstává v telefonu. Účet není. Zálohu exportuješ v Nastavení, když chceš kopii.

Na Galaxy Z Flip telefon v půlce složíš: cvik a časovač pauzy zůstanou na horní polovině, tlačítka sérií na spodní, kam dosáhneš. Na Galaxy Z Fold otevřený displej rozdělí cvik a série do dvou sloupců a při pootevření nechá pant volný. Krycí displej Flipu ukáže časovač pauzy, pokud necháš aplikaci na krytu běžet.

**Novinky:** První verze pro Galaxy. Rozložení pro telefon, Z Flip a Z Fold.

## Screenshot plan

Take these after the signed build is on a device, in dark mode, with a workout in progress so the rest timer is visible. PNG, no status-bar clutter if the portal’s examples are clean.

| Store slot | Size to aim for | What to show |
|---|---|---|
| Phone 1 | 1440×3120 or 1080×2400 | Today’s generated workout |
| Phone 2 | same | Logging a set, rest timer visible |
| Phone 3 | same | History |
| Phone 4 | same | Exercise progress |
| Flip, half-folded | phone size, or a photo of the device | Exercise and timer on top, sets on the bottom |
| Flip cover | the cover’s resolution (Flip5/6 are nearly square, about 720×748 or 968×1048 physical) | Rest-timer glance |
| Fold, open | tablet slot, inner display (Fold5/6 inner is roughly 1812×2176 or 1856×2160) | Two-pane logger, nav along the side |
| Fold, book | same, phone held half-open | Exercise on one side of the hinge, sets on the other |

Layout proofs from this repo, shot in Chrome at those window sizes:

| File | Viewport | Layout |
|---|---|---|
| `samsung/screenshots/phone-compact.png` | 390×844 | Compact phone, bottom tabs |
| `samsung/screenshots/flip-flex.png` | 412×900, Flex | Top: exercise and rest. Bottom: sets |
| `samsung/screenshots/fold-expanded.png` | 1280×800 | Large window, side nav, two panes |
| `samsung/screenshots/fold-book.png` | 1100×840, book | Vertical hinge |
| `samsung/screenshots/flip-cover.png` | 360×380 | Cover glance |
| `samsung/screenshots/tv-home.png` | 1920×1080 | TV start screen |
| `samsung/screenshots/tv-workout.png` | 1920×1080 | TV follow-along |

Preview any fold layout in a desktop browser without a device:

```text
http://localhost:8000/?fold=flex
http://localhost:8000/?fold=book
http://localhost:8000/?fold=cover
```

On a real Flip or Fold the `?fold=` query is ignored, because the Android bridge reports the hinge.

## Foldables

Window size classes follow Material widths: compact under 600px, medium under 840, expanded under 1200, large under 1600, extra-large from 1600. Height uses 480 and 900. A normal Galaxy phone stays on the existing layout.

**Flex Mode (Z Flip, half-folded).** WindowManager reports `HALF_OPENED` with a horizontal hinge. The exercise and the rest timer stay in the top segment. Set buttons, and on other screens the primary action, move to the bottom segment. The page is not reloaded, so a half-typed weight survives the fold. `configChanges` includes `screenSize`, `smallestScreenSize`, `screenLayout`, and `density`, so Android does not recreate the activity.

**Book (Z Fold, half-open).** A vertical hinge. The exercise stays on the left, the sets on the right, and the hinge gap is left empty. Fully open, the hinge is not a gap: the inner display is just a large window (side navigation from 840px, two columns for the logger).

**Continuity.** The workout already lives in local storage, including the rest timer’s end time. In the Android app and in an installed PWA, an empty launch restores the last route. A normal browser tab does not, so the website still opens on today’s workout.

**Multi-window and pop-up.** The activity is resizable and not locked to portrait. A pop-up or a split screen is just a smaller window class. DeX and a wide window get the large layout. The bridge sets `data-multiwindow` when Android says the app is in multi-window.

**Cover screen.** One UI does not let a normal store app draw a Flip cover widget. Those widgets are a separate Good Lock format. What does work: Settings → Advanced features → Labs (the label moves between One UI versions) → allow this app on the cover screen, sometimes worded “Continue apps on cover screen”. Closing the Flip then resizes this activity onto the cover. The glance shows the exercise name, the workout clock or the rest timer, and −15 / +15 / Skip. It does not try to be the full set logger. Open the phone to log. Flip 3/4 covers are a narrow strip; Flip 5/6 covers are a small square. Both sizes use the glance. A normal phone and a pop-up do not.

## Samsung TV (The Serif, 2022)

A TV version is worth it. The set logger is a few remote actions: pick the exercise, pick the set, confirm it, wait out a rest you can read from across the room. The Serif is a living-room set. The phone app remains the full log (charts, custom exercises, backup). The TV app is the follow-along.

Tizen 6.5 on that set is a Chromium engine around M85. The TV package does not load the phone CSS, and its script plus `data.js`, `store.js`, and `engine.js` stay off APIs that M85 does not have (`Array.prototype.at`, `replaceAll`, `findLast`). `npm test` checks that. System fonts are used instead of Google Fonts, so the TV does not need a network. There is no internet privilege in `config.xml`.

The TV has its own storage. It does not sync with the phone. Same idea as the website: each device keeps its own log.

Build and install with AeroTizen, which signs a folder or a `.wgt` with the TV’s certificate:

```sh
npm run tizen
aerotizen install tizen/dist
```

`tizen/Overload.wgt` is the same files zipped, if you would rather pass a file: `aerotizen install tizen/Overload.wgt`.

On the TV, once:

1. Open Apps and type `12345` (on some firmware that only works from Apps → App Settings). Turn Developer mode on and set Host PC IP to your computer. Check all four numbers.
2. Unplug the TV for a minute. Turning it off with the remote is not enough.
3. From the computer: `aerotizen discover`, then `aerotizen certs` (Samsung sign-in, once), then the install command above.

`config.xml` asks for Tizen 6.5 (`required_version="6.5"`), profile `tv-samsung`, app id `overloadtv.main`. If the install complains that the platform version is too high, lower `required_version` to `6.0` and run `npm run tizen` again.

Remote, in a workout:

| Key | Action |
|---|---|
| Up / Down | Previous / next exercise |
| Left / Right | Previous / next set |
| OK / Enter | Log the set (weight and reps prefilled from last time) and start the rest |
| Yellow / Blue | Decrease / increase the weight by your usual plate step. On a keyboard, `-` and `+` |
| Red | Skip the rest |
| Green | Finish, then confirm save or discard |
| Back | Leave the session on screen. The workout keeps running. Back on the home row resumes it |

The focused row has a yellow ring. You do not need a pointer.

## CI

`.github/workflows/android.yml` runs the unit tests, builds the Tizen package, syncs the web assets, and runs `assembleDebug` and `bundleRelease` on Ubuntu with JDK 21. The release bundle from CI is unsigned, because the keystore is not in the repo and not in GitHub secrets. Add the four `ANDROID_KEYSTORE_*` secrets later if you want CI to sign. Don’t put the keystore file in the repository to make that work. `actions/upload-artifact` keeps the APK, the AAB, and `tizen/Overload.wgt`.

## Risks

- These layouts were checked in Chrome at Flip, Fold, cover, and 1080p sizes, and the Android project was compiled here. They were not installed on a physical Z Flip, Z Fold, or The Serif. Flex Mode in particular depends on the device reporting `HALF_OPENED`. If a One UI build stays `FLAT` until a sharper angle, the split waits for that report. Confirm on your Flip at about 90 degrees.
- The cover glance only appears when One UI actually puts the activity on the cover. There is no supported way to ship a cover-screen widget inside this APK.
- The Device Posture API in the system WebView lags Chrome. The shell does not rely on it. A PWA opened in Samsung Internet might not split until that browser ships the API. The size-class layout (two panes when the window is wide) still applies.
- TV and phone logs are separate. There is no sync. A backup file from the phone is not imported on the TV.
- If the The Serif’s browser engine is older than the M85 estimate, the symptom is a blank TV app. The package is small enough to inspect from AeroTizen’s debugger (`aerotizen inspect` once the app is installed).
- Store review can still reject a health-related app, or ask for a different screenshot size, a content rating, or a newer target SDK than 36. The privacy page and the data-safety answers above match what the app does today: local storage, no account, no analytics.
- Losing the upload keystore blocks updates. Keep a copy outside the computer you develop on.
