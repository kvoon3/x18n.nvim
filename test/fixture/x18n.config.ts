import { defineConfig } from '@x18n/core'

/** `{name}` spans, the placeholder shape used by the fixture messages. */
const braces = {
  id: 'braces',
  example: '{name}',
  find(value: string) {
    const out = []
    for (const match of value.matchAll(/\{([\w.-]+)\}/g)) {
      out.push({
        syntax: 'braces',
        text: match[0],
        name: match[1],
        range: { start: match.index, end: match.index + match[0].length },
      })
    }
    return out
  },
}

export default defineConfig({
  name: 'playground',
  sourceLocale: 'en',
  // The server reports [sourceLocale, ...found.sort()]; this array defines membership, not order.
  locales: ['en', 'zh-CN', 'ja', 'fr'],
  resources: [{ pattern: 'locales/{locale}.json' }],
  plugins: [{ name: 'fixture:placeholders', placeholders: [braces] }],
  usage: {
    calls: [{ callee: 't', params: { arg: 1 } }],
  },
})
