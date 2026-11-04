# Server compatibility

x18n.nvim talks to any x18n 0.1.9 server that implements the `x18n/*` protocol. The published `@x18n/lsp` 0.1.9 covers standard LSP and the shared custom methods. The `kvoon3/x18n` fork adds `x18n/keyInfo` and a few fields that the richer UI uses.

## Standard LSP and shared methods

These work with the published server:

- completion inside key slots, hover, definition, implementation, references, rename, code actions, inlay hints and diagnostics
- `x18n/projects`, `x18n/keyAt`, `x18n/tree`, `x18n/progress`, `x18n/fileKeys`, `x18n/usageReport`, `x18n/search`, `x18n/decorations`, `x18n/setDisplayLocale`, `x18n/openUi`, `x18n/translatePrompt`, `x18n/reviews`, `x18n/explain` and `x18n/changed`
- the `x18n.extract` and `x18n.set` commands

## Fork-only behavior

The fork adds `x18n/keyInfo` and the fields below. Without it, the plugin falls back in the listed way.

| Feature | Contract | Without the fork |
| --- | --- | --- |
| Translations popup (`gh`, `:X18nShowTranslations`) | `x18n/keyInfo` | `gh` falls back to the native hover |
| Copy translation | `x18n/keyInfo` | notifies that the fork is needed and copies nothing |
| Per-locale add menu (`Ctrl+.`) | `x18n/keyInfo` | native code actions |
| Locale labels in `:X18nDefinition` and `:X18nKeys choose_locale` | `keyInfo.locales[].present` | the quickfix and picker list definition files by name |
| Usage badges in locale files | `x18n/fileKeys[].usages` | the badge is omitted |
| Completion documentation | `completionItem/resolve` | items keep the source value as detail |
| Param-filled inline values | filled `Decoration.value` | placeholders stay as written |
| Inline values in a component with an embedded `<i18n>` block | non-empty `x18n/decorations` | the file is treated as a locale file |

The param change also enables the existing `param-mismatch` check for Vue I18n
calls. The fork can report a diagnostic the published server does not.

## x18n/keyInfo

Request params are `{ uri, position }`. The server resolves the key at the position, including anywhere inside the call and the line-end annotation when the line has one key.

```ts
interface KeyInfoResult {
  project: string
  key: string
  type: 'key' | 'subtree'
  label?: string
  range: Range
  locales: {
    code: string
    flag?: string
    value?: string
    state?: string
    changed?: string
    outdated: boolean
    source: boolean
    present: boolean
  }[]
  threads: { locale: string, state: string }[]
  usages: number
}
```

`present` says whether the locale defines the key. `value` is the raw message with static call params filled, not markdown. The plugin pairs implementation locations with the locales that have `present: true`.

## Checking compatibility

Run the plugin tests against the published server:

```sh
make test-upstream
```

The target installs `@x18n/lsp@0.1.9` under `test/upstream` on first use. Tests
that need the fork print `skipped, needs the x18n fork`. The rest must pass. Set
`X18N_LSP_BIN` to point the suite at another server binary.
