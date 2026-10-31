# Playground

A self-contained project for trying x18n.nvim against a real `x18n-lsp`:
three locales, every decoration state, hard-coded strings to extract.

## Run

```sh
cd playground
npm install
nvim -u init.lua
```

`init.lua` prepends the repository to `'runtimepath'`, puts
`playground/node_modules/.bin` first on `PATH`, and opens `src/main.ts` once
filetype detection is ready. Nothing from your `~/.config/nvim` is loaded.

## What to try

| Action | Expected |
| --- | --- |
| Normal mode | Every `t('key')` is replaced by its English translation (`title: Task Board`). |
| `K` on a replaced call | Float with the hidden source (`t('app.title')`) and a row for every locale (en, zh-CN, ja). |
| `i` inside a call | The real source returns while editing; decorations come back on `Esc`. |
| `:X18nDisplayLocale zh-CN` | All replacements switch to Chinese; `K` highlights the current locale. |
| `:X18nUsageReport` | Quickfix with missing `task.delete` and unused `toast.legacy`. |
| `:X18nSearch save` | Search by translated value; pick a result to jump into its locale file. |
| `:X18nExtract` in `src/settings.ts` | Hard strings become keys in `locales/en.json`, ready for translation. |
| `:checkhealth x18n` | Server found, running, attached. |

## Notes

- Locale resources: `locales/{en,zh-CN,ja}.json`; config: `x18n.config.ts`.
- `task.delete` is intentionally missing and `toast.legacy` intentionally unused.
- After `:X18nExtract`, `:wa` writes the rewritten buffer and the new locale keys.
- `vim.g.x18n_debug = true` in `init.lua` prints protocol traffic to the command line.
