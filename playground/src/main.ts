import { t } from 'x18n/runtime'

export function renderHeader() {
  return {
    title: t('app.title'),
    subtitle: t('app.subtitle'),
    save: t('button.save'),
    cancel: t('button.cancel'),
  }
}

export function renderList(tasks) {
  return {
    empty: t('task.empty'),
    label: t('task.count', { count: tasks.length }),
    add: t('task.new'),
  }
}

export function notify(text) {
  toast(text)
}

export function removeTask(id) {
  return t('task.delete', { id })
}

export function announce() {
  return t('toast.saved')
}
