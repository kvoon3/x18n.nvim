import { defineConfig } from '@x18n/core'

export default defineConfig({
  name: 'playground',
  sourceLocale: 'en',
  locales: ['en', 'zh'],
  resources: [{ pattern: 'locales/{locale}.json' }],
  usage: {
    calls: [{ callee: 't' }],
  },
})
