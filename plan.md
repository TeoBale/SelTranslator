# SelTranslator Plan (Next Steps)

Scope: This document outlines the plan to solidify the public core API exposure, ensure concurrency safety, and complete validation of the build/tests and UI behavior across macOS environments.

Status
- Build: Successful for the current target (arm64 macOS 15+). Tests: Unable to run in this environment due to XCTest not being available in the container; can run on macOS CI.

What changed (high level)
- Exposed core types publicly to bridge modules:
  - TranslationLanguage (Sendable, public properties, public helpers)
  - TranslationLanguageStore (public, public API)
- UI fixes to compile in bridged contexts:
  - StatusBarController: explicit NSControl.StateValue for menu item state
  - SettingsWindowController: explicit closure parameter types for SwiftUI bridges
- Added concurrency-safe conformance guidance via Sendable for TranslationLanguage.

Rationale
- Public core types are necessary for a clean multi-module architecture; bridging via ModuleAliases depended on this visibility.
- Concurrency warnings from the compiler were addressed by making types Sendable and using explicit types where needed.

Next Steps (Plan)
1) Testing and CI
- Add and/or enable a macOS-based CI workflow to run swift test on mac runners.
- Ensure XCTest is available in CI environment to run the core tests.

2) Unit Tests for Core API
- Write tests for TranslationLanguage.all, TranslationLanguage.fallback, and TranslationLanguageStore.selectedLanguage behavior when stored or missing.
- Cover edge cases where stored language is not in availableLanguages.

3) Documentation
- Maintain a short API doc in code or README about how to use TranslationLanguage and TranslationLanguageStore across modules.

4) Validation of UI behavior
- Manual QA to ensure that UI components compile and render correctly on macOS versions supported by the project.
- Validate bridging via ModuleAliases remains stable as modules evolve.

5) Plan for future changes
- If more core types need to be bridged, consider a dedicated bridging layer or service to avoid tight coupling between modules.

Todo
- [ ] Write unit tests for core API (TranslationLanguage, TranslationLanguageStore)
- [ ] Configure/verify macOS CI to run tests
- [ ] Add lightweight API docs for bridging usage
- [ ] Execute a full, local build and report any regressions
