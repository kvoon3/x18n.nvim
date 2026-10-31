const messages = {
  app: {
    title: 'Hello x18n',
  },
}

export function t(key) {
  return key
}

export const greeting = t('app.title')
export const broken = t('app.missing.key')
export const hardString = 'not translated yet'
