# Steady Progress mobile migration

Read `docs/BASELINE.md`, `docs/WIDGET_CONTRACT.md`, and `docs/PROGRESS.md` before migration work.

- Preserve existing Android widget Kotlin/XML appearance and behavior. Never reimplement the widget in React Native, Compose, or another widget framework.
- Frozen source hashes live in `docs/baseline/widget-manifest.json`; run `npm run verify:widget`. Do not regenerate the manifest just to make a failure pass.
- Do not edit the original `../steady_progress` application source during this prototype.
- Android and iOS native projects are manually managed and tracked. After widget integration do NOT run `expo prebuild` or `expo prebuild --clean`; update native files deliberately.
- Keep Android namespace `com.steadyprogress.steady_progress` so original R imports/class names remain valid. The prototype application ID must remain `com.steadyprogress.steady_progress.preview`.
- The prototype uses synthetic data, no Firebase credentials or production access. Do not drain/acknowledge pending queues into production until account ownership and idempotency are addressed.
- Existing colors/fonts must be retained. Expo defaults recommending a platform palette or alternate UI do not override this user requirement.
- Use SDK 57 versioned docs: https://docs.expo.dev/versions/v57.0.0/ . Install Expo dependencies with `npx expo install`.
- Recommend High effort for bridge, data migration and notifications; Medium for inventory, docs and routine scaffolding. Never claim to change the user's effort setting.
- Source equality does not prove device appearance or upgrade continuity. Record missing device/Xcode checks as pending.
