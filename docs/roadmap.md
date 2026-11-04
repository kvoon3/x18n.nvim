# Roadmap

- Param filling beyond simple placeholders: evaluate plural/select branches,
  format numbers and dates by locale, and resolve params from props, imports
  and other non-const expressions
- Per-call previews in hover and completion docs: today both show the stored
  message per key; decide whether they fill the current usage's static params
  and label the result as a preview
- Share `ScanScope` with the Svelte scanner so template expressions resolve
  `<script>` constants, as Vue does now
- Locale tree explorer (`x18n/tree`), review threads (`x18n/reviews`)
- Copy translate prompt (`x18n/translatePrompt`)
