# Server compatibility

x18n.nvim talks to any x18n 0.1.10 server that implements the `x18n/*` protocol. The published `@x18n/lsp` 0.1.10 covers standard LSP, the shared custom methods, all-locale completion docs and inline values in components with an embedded `<i18n>` block. The `kvoon3/x18n` fork adds `x18n/keyInfo` and param-filled values.

## Standard LSP and shared methods

These work with the published server:

- completion inside key slots, including `completionItem/resolve` with the all-locale documentation panel, plus hover, definition, implementation, references, rename, code actions, inlay hints and diagnostics
- `x18n/projects`, `x18n/keyAt`, `x18n/tree`, `x18n/progress`, `x18n/fileKeys`, `x18n/usageReport`, `x18n/search`, `x18n/decorations`, `x18n/setDisplayLocale`, `x18n/openUi`, `x18n/translatePrompt`, `x18n/reviews`, `x18n/explain` and `x18n/changed`
- the `x18n.extract` and `x18n.set` commands

## Fork-only behavior

The fork adds `x18n/keyInfo` and the fields below. Without it, the plugin falls back in the listed way.

| Feature | Contract | Published 0.1.10 fallback |
| --- | --- | --- |
| Translations popup (`gh`, `:X18nShowTranslations`) | `x18n/keyInfo` | `gh` falls back to the native hover |
| Copy translation | `x18n/keyInfo` | notifies that `x18n/keyInfo` is required and copies nothing |
| Per-locale add menu (`Ctrl+.`) | `x18n/keyInfo` | native code actions |
| Locale labels in `:X18nDefinition` and `:X18nKeys choose_locale` | `keyInfo.locales[].present` | the quickfix and picker list definition files by name |
| Param-filled inline values | filled `Decoration.value` | placeholders stay as written |
| `param-mismatch` diagnostics for Vue I18n calls | param positions declared by the preset | the check stays quiet |

Param filling rides on the preset's declared param positions, so the existing
`param-mismatch` check also fires for Vue I18n calls on the fork.

Locale-file usage badges need `x18n/fileKeys[].usages`. When the server reports
no usage counts, the display-locale value is shown instead. Set
`show_locale_file_eol_translation = false` to omit it.

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

`make test` runs the suite against the published server from the root
devDependency (`@x18n/lsp` 0.1.10). The harness probes `x18n/keyInfo`; tests
that need the fork print `skipped, needs the x18n fork`. Everything else must
pass.

To exercise the fork features too, build the fork and point `X18N_LSP_BIN` at
its server entry:

```sh
X18N_LSP_BIN=~/f/x18n/packages/lsp/bin.mjs make test-fork
```

`make test` also honors `X18N_LSP_BIN`, so you can use it with any other server
binary.
