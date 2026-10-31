import { defineConfig } from '@x18n/core'

export default defineConfig({
  sourceLocale: 'en',
  locales: ['en', 'zh-CN', 'ja'],
  resources: [{ pattern: 'locales/{locale}.json' }],
  usage: { calls: [{ callee: 't' }] },
})
