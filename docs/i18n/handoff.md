# i18n handoff — Indian language support

Date: 2026-11-16 · Repo: `cake_wallet` (branch `main`, `499b6f446`) · All work below is **local, uncommitted, no PR opened**.

## 1. Mission

Repair Hindi and add Bengali, Marathi, Tamil, Telugu to Cake Wallet.

Target locales and codes (plain ISO 639-1, no region suffix — see §7 traps):

| Locale | Code | Script | Unicode | Flag key (`localeCountryCode`) | Status |
|---|---|---|---|---|---|
| Hindi | `hi` | Devanagari | U+0900–097F | `ind` | exists, needs repair |
| Marathi | `mr` | Devanagari | U+0900–097F | `ind` | new |
| Bengali | `bn` | Bengali | U+0980–09FF | `bgd` | new |
| Tamil | `ta` | Tamil | U+0B80–0BFF | `ind` | new |
| Telugu | `te` | Telugu | U+0C00–0C7F | `ind` | new |

Constraints from the requester:

- Minimal PRs, **no code comments** in committed code.
- Everything tested end-to-end **before** any PR is opened.
- No PR from the assistant; changes stay in the working tree.
- Weblate was evaluated and **dropped** — do not design around it. Git/ARB is the source of truth.

## 2. Repo mechanics (read this before touching strings)

- Strings live in `res/values/strings_<code>.arb`, 32 files. English is `strings_en.arb`, **1174** keys.
- Placeholders are Dart interpolation: `${name}` — **not** ICU `{name}`. `strings_en.arb` has **zero** ICU plural rules, so count strings are sentence-level and rely on phrasing.
- No `@key` metadata exists: 0 of 1174 keys have descriptions or declared placeholders.
- `lib/generated/` is **gitignored** (`.gitignore:109`). `tool/generate_localization.dart` runs during every build: `configure_cake_wallet.sh:39`, `scripts/linux/build_cake_release.sh:76`, `.github/workflows/reusable-build.yml:189`. Never hand-edit `lib/generated/i18n.dart`; never commit it.
- Adding a language (per `README.md:158`): ARB file → `lib/entities/language_service.dart` (`supportedLocales` + `localeCountryCode`) → flag PNG in `assets/images/flags/` (42×26, 3px transparent margin) → `tool/utils/translation/translation_constants.dart`.
- The language picker renders `assets/images/flags/<localeCountryCode>.png` (`lib/src/screens/settings/display_settings_page.dart:91`), so a flag exists per language only via that map. `ind.png`, `bgd.png`, `pak.png`, `lka.png` already exist.
- Flutter's own Material/Cupertino strings are available for `hi`, `bn`, `mr`, `ta`, `te` (and `gu`) — verified in the SDK's `flutter_localizations/lib/src/l10n/generated_material_localizations.dart`. `lib/locales/locale.dart` already registers `GlobalMaterialLocalizations` / `GlobalCupertinoLocalizations`, so pickers, date formats and copy/paste menus localize for free.
- `ios/Runner/Info.plist` has `CFBundleDevelopmentRegion` but **no** `CFBundleLocalizations` — iOS will not list new languages in the app-language picker until that array is added.

## 3. Verified findings

### 3.1 Hindi is complete but drift-ridden (MT output, no glossary)

`res/values/strings_hi.arb`: 1173/1174 keys translated. 15 values are byte-identical to English: 7 are in the linter's brand allowlist (`cake_wallet`, `monero_com`, `faq`, …), 2 are single short tokens the linter treats as proper nouns (`usb`, `yat`), and **6 are genuinely untranslated** (`address_label`, `overwrite_amount`, `qr_payment_amount`, `time`, `view_in_block_explorer`, `view_transaction_on`).

Measured term variants (occurrences across the whole file):

| Term | Observed renderings | Reading |
|---|---|---|
| wallet | वॉलेट 107 · बटुआ 30 · पर्स 3 | three terms in use |
| seed phrase | बीज 51 · बीज वाक्यांश 4 · सीड 2 · वसूली 2 | वसूली means "recovery" |
| address | पता 41 · पते 28 · एड्रेस 1 | inflection, acceptable |
| backup | बैकअप 26 · बैक-अप 2 | hyphen drift |
| transaction | लेनदेन 29 · लेन-देन 18 | hyphen drift |
| exchange | एक्सचेंज 8 · विनिमय 2 · अदला-बदली 1 | three terms |
| fee | शुल्क 26 · फीस 6 | two terms |
| balance | शेष 23 · बैलेंस 10 | two terms |
| trade | व्यापार 16 · ट्रेड 7 | two terms |
| passphrase | पासफ्रेज़ 3 · पासफ्रेज 4 | nukta drift |
| block | ब्लॉक 13 · खंड 1 | — |
| currency | मुद्रा 12 · करेंसी 2 | — |

Punctuation: danda `।` in 154 of 1175 strings; the rest use ASCII periods or nothing. 159 strings contain Latin words (brand names and untranslated tokens).

Other `hi` defects: 2 stale keys not in English (`Payment_was_received`, `ready_have_account`), 1 missing key (`passphrase_view_keys`, currently falls back to English).

### 3.2 Untranslated / incomplete locales (silent English fallback)

The generated `class $xx extends S` only overrides keys present in that ARB, so a missing key renders English without any warning:

| Locale | Missing keys |
|---|---|
| `gn` | 268 |
| `vi` | 5 |
| `hy`, `zh_TW` | 3 each |
| `fa`, `pl`, `pt_BR` | 2 each |
| 23 others (`ar`, `bg`, `cs`, `de`, `es`, `fr`, `ha`, `hi`, `hr`, `id`, `it`, `ja`, `my`, `nl`, `pt`, `ru`, `th`, `tl`, `tr`, `uk`, `ur`, `yo`, `zh`) | 1 each |

### 3.3 Placeholder handling is fragile (latent semantic corruption)

- `tool/generate_localization.dart:128-152` derives each locale method's parameter list from **that locale's** placeholders and calls it positionally from the English signature. A renamed placeholder is harmless; a **reordered** one renders the wrong value.
- `tool/utils/translation/translation_utils.dart:39-45` re-substitutes placeholders **by index** after MT, which breaks on reorder.
- Real pre-existing cases: `yo/error_text_maximum_limit` says *minimum* while receiving the `max` value; `gn/do_not_have_enough_gas_asset` drops one `${currency}`; `pt`/`pt_BR` rename `${value}`→`${valor}`; `ar/minutes_to_pin_code` renames `${minute}`→`${minutes}`.

### 3.4 Generator drops regional locale codes

`tool/generate_localization.dart:56` does `path.split('_')[1].split('.')[0]`, so `strings_pt_BR.arb` → `pt` and `strings_zh_TW.arb` → `zh`; whichever directory entry is read last wins and `Locale("pt","BR")` is never emitted. The matching `tool/utils/translation/arb_file_utils.dart:getArbFileName` splits on `-` instead. Consequence: `pt_BR` and `zh_TW` are not shipped as distinct locales.

Harmless for `hi/mr/bn/ta/te` (plain codes). Blocks any regional code later.

### 3.5 `@key` metadata would break codegen

`tool/generate_localization.dart:131` casts every value with `value as String`. An ARB metadata map (`"@key": {...}`) throws `_TypeError`, and the generator runs on every build — so descriptions must not be added before the cast is made metadata-aware.

### 3.6 Indic glyphs are not bundled

`pubspec.yaml:376` declares `Wix Madefor Text` (Latin/Cyrillic/Vietnamese only — no Indic coverage); `assets/fonts/` in this checkout contains only `Lato-*.ttf`. All Indic text therefore renders through the platform fallback (Android Noto, iOS Kohinoor/Bangla Sangam/Gujarati Sangam etc.), so weights and metrics differ from Latin. Sample: `assets/fonts/` listing; Wix Madefor script coverage is documented by Dalton Maag.

### 3.7 CI gate was JSON-only

`.github/workflows/are_translations_sane.yml` previously only ran `jq` on each ARB file. It would not catch the §3.3 defects.

## 4. Work already in the working tree (uncommitted)

**These files exist only on this machine.** `tool/i18n_lint.dart`, `tool/i18n_baseline.json`, `tool/gen_review_sheet.dart` and `docs/i18n/` are untracked; `.github/workflows/are_translations_sane.yml` is modified. From a clean checkout none of this is visible and `git log` shows nothing — port or copy the files before relying on the commands in §8. `docs/i18n/review_*.md` are generated output, not hand-written.

| File | Purpose | Verification |
|---|---|---|
| `tool/i18n_lint.dart` (342 ln) | Key parity, `${placeholder}` integrity (dropped/duplicated/reordered), unbalanced braces, empty values, per-locale script coverage, stray English, length ratio, leading/trailing space parity, terminal punctuation with full-width/Indic/Armenian/Myanmar equivalents | `dart tool/i18n_lint.dart` → `0 error(s), 0 warning(s), 1211 baselined`; injecting a dropped placeholder into `strings_hi.arb` produced `error hi ph-dropped max_amount drops value` |
| `tool/i18n_baseline.json` | 1211 accepted findings so the gate can land without a big-bang cleanup | `jq '.accepted|length'` → 1211 |
| `.github/workflows/are_translations_sane.yml` (modified) | jq parse + `dart tool/i18n_lint.dart` on every PR | — |
| `tool/gen_review_sheet.dart` (203 ln) | Reviewer worksheet: key, screen, English, current, flags; tiers 1–3 | `dart tool/gen_review_sheet.dart --lang=hi` → 1176 rows (tier1 326, tier2 255, tier3 595) in 0.3 s |
| `docs/i18n/review_hi*.md` | Generated output (full / gaps) | — |

Baseline is 1211 **findings** (errors + warnings), from `tool/i18n_baseline.json`: `gn` 335 (268 missing, 38 punctuation, 14 space, 8 extra, 4 length, 3 empty) · `hy` 156 (141 punctuation, 6 script, 3 identical, 3 missing, 2 length, 1 space) · `ar` 98 · `my` 96 · `ur` 74 · `bg` 61 · `ja` 35 · `ru` 32 · `hi` 29 · `zh_TW` 17 · `vi` 13, then the rest at ≤10 each. Do not read these as missing-key counts; §3.2 lists those.

`hi`'s 29: 1 missing, 2 stale, 6 identical-to-English, 6 no-Devanagari, 8 punctuation, 3 length, 2 space, 1 placeholder order.

CLI:

```
dart tool/i18n_lint.dart [--lang=hi,bn] [--strict] [--update-baseline]
dart tool/gen_review_sheet.dart --lang=hi[,bn] [--gaps-only] [--tier=1]
```

## 5. Decisions

Settled:

- Bengali flag = `bgd` (majority-speaker convention already used by `hi`→`ind`, `ur`→`pak`, `pt_BR`→`bra`). `bgd.png` exists; no code change needed.
- INR lakh/crore grouping: **deferred**, tracked as a separate issue (amount formatting is hand-rolled; `NumberFormat` usage is commented out at `lib/core/amount.dart:21`).
- Scope: Hindi's 29 findings are in scope; the other 1182 baseline findings become separate issues.
- No PRs, no code comments, full end-to-end testing before any PR.

Open:

- Commit generated review sheets, or generate on demand? Recommendation: commit only `*_gaps.md` (small, changes only when an issue appears); full sheets are 198 KB and regenerate in 0.3 s.

## 6. Plan

| Wave | Work | Eng | Native review |
|---|---|---|---|
| 0a | `localizedStrings()` skips `@`-prefixed keys (incl. `@@locale`) instead of casting; add `--outDir=` so codegen is testable | 0.5d | — |
| 0b | CI codegen smoke test: run the generator into a temp outDir on every PR; assert exit 0 and that emitted classes match the set the current tool derives from the ARB filenames (today 29 — regional codes collapse, so `pt_BR`/`zh_TW` are absent by design *of the bug*). Do **not** assert `pt_BR`/`zh_TW` classes; a separate fix changes both the split and this assertion together. | 0.5d | — |
| 0c | `@key` descriptions + declared placeholders in `strings_en.arb` (after 0a/0b) | 1d | — |
| 0d | Placeholder token sentinels replacing index substitution in `translation_utils.dart`; retire Google-Translate path for reviewed locales | 0.5d | — |
| 0e | Glossary skeletons: `hi` seeded with the §3.1 counts, `mr`/`bn`/`ta`/`te` tables for reviewers | 0.5d | — |
| 0f | Font fallback decision (bundle Noto Devanagari/Bengali/Tamil/Telugu vs accept platform fallback + fix clipping) | 1d | — |
| 1 | `hi` repair (Tier 1 → 2 → 3) · `mr` draft + review | 1d | 3d + 3.5d |
| 2 | `bn` draft + review | 0.5d | 3.5d |
| 3 | `ta`, `te` draft + review | 1d | 7d |

`mr` reuses Hindi's Devanagari font/shaping work but **not** its terminology; Marathi technical vocabulary must be authored independently.

Reviewer throughput assumption: 250–350 strings/reviewer-day with MT drafts + glossary. Tier 1 = onboarding, seed/backup, PIN, dashboard, send. Tier 2 = receive, transactions, settings, security, exchange. Tier 3 = everything else, deferrable per locale (cuts `ta`/`te` review from 7 to ~4 days).

Definition of done per locale: 0 missing keys · 0 new lint findings · 0 glossary outliers · screenshots clean at text scale 1.0/1.15/1.3 across 12 screens on iOS and Android · native sign-off attached.

## 7. Traps

1. Do not add `@key` metadata before 0a — it breaks every build, not just lint.
2. Do not run `tool/generate_localization.dart` for any code containing `_` or `-`.
3. Do not run `tool/translation_consistence.dart --fix` on reviewed locales: it fills gaps with Google Translate and rewrites files alphabetically.
4. Do not hand-edit `lib/generated/*`. It is gitignored and build-generated.
5. Leading/trailing spaces in values are load-bearing (`auth_store_banned_minutes` = `" minutes"`); the lint flags mismatches because dropping them corrupts concatenated UI text.
6. `tool/utils/translation/translation_constants.dart` lists `zh-cn`/`zh-tw` while the files are `zh`/`zh_TW`; do not copy that pattern.
7. Hindi/Bengali/Marathi/Tamil/Telugu use one/other plural only. Phrase count strings neutrally; true plural support needs code changes (`_one`/`_other` keys), not ARB edits.
8. Use ASCII digits for amounts in all five locales; state it in the style guide so reviewers do not switch scripts mid-number.

## 8. Reproduce every claim

```
dart tool/i18n_lint.dart                       # full audit vs baseline
dart tool/i18n_lint.dart --lang=hi
dart tool/gen_review_sheet.dart --lang=hi      # 1176 rows, tiers 326/255/595
dart tool/gen_review_sheet.dart --lang=hi --gaps-only

# key coverage / term drift
python3 - <<'EOF'
import json,re
en=json.load(open('res/values/strings_en.arb')); hi=json.load(open('res/values/strings_hi.arb'))
enk={k:v for k,v in en.items() if isinstance(v,str)}; hik={k:v for k,v in hi.items() if isinstance(v,str)}
print('missing', [k for k in enk if k not in hik])
print('identical', sum(1 for k in enk if hik.get(k)==enk[k]))
vals=list(hik.values())
for t in ['वॉलेट','बटुआ','पर्स','लेनदेन','लेन-देन','बैकअप','बैक-अप']:
    print(t, sum(v.count(t) for v in vals))
EOF
```

## 9. Not done

- No PR, no commit, no Jira issue filed (no Jira access in this environment).
- `@key` metadata not added; generator not yet metadata-safe.
- Placeholder sentinel fix not applied.
- Glossary not written (term data is in §3.1).
- Font fallback not decided; no Indic font bundled.
- `CFBundleLocalizations` not added to `ios/Runner/Info.plist`.
- No locale added yet: `bn`/`mr`/`ta`/`te` ARBs, `language_service.dart` entries, and flags are untouched.
- Screenshot sweep harness not built.
- `pt_BR`/`zh_TW` generator bug not fixed or filed.
