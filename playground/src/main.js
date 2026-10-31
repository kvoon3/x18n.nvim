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
// The next line keeps multibyte text ahead of the key on the same line, so a
// byte column and a UTF-16 column land on different offsets inside it. The CJK
// run is long enough that the divergence outruns the key itself.
export const withCjk = pad('中文前缀一二三四五六七八九十') + t('app.description')
export const hardString = 'not translated yet'
