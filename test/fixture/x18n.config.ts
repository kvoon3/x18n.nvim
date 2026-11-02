import { defineConfig } from '@x18n/core'

export default defineConfig({
  name: 'playground',
  sourceLocale: 'en',
  // The server reports [sourceLocale, ...found.sort()]; this array defines membership, not order.
  locales: ['en', 'zh-CN', 'ja', 'fr'],
  resources: [{ pattern: 'locales/{locale}.json' }],
  usage: {
    calls: [{ callee: 't' }],
  },
})
