export function settingsView(user) {
  return {
    label: 'Settings',
    greeting: `Welcome back, ${user.name}`,
    hint: 'Changes are saved automatically',
  }
}
