-- Playground projects and the source files that hold i18n calls. The checker
-- copies each project to a temp dir before driving it, so every path here is
-- relative to the project directory. `markers` are the plugin root_markers for
-- that project: the monorepo file must root at the directory that owns
-- x18n.config.ts, not at apps/web/package.json.
return {
  {
    name = 'vue-vite',
    markers = { 'package.json' },
    files = { 'src/App.vue', 'src/components/TodoList.vue', 'src/main.ts' },
  },
  {
    name = 'react-i18next',
    markers = { 'package.json' },
    files = { 'src/Cart.tsx', 'src/Login.tsx' },
  },
  {
    name = 'next-intl',
    markers = { 'package.json' },
    files = { 'app/[locale]/page.tsx', 'app/[locale]/pricing/page.tsx' },
  },
  {
    name = 'laravel',
    markers = { 'composer.json' },
    files = { 'resources/views/dashboard.blade.php', 'app/Http/Controllers/LoginController.php' },
  },
  {
    name = 'rails',
    markers = { 'Gemfile' },
    files = { 'app/views/users/index.html.erb' },
  },
  {
    name = 'angular',
    markers = { 'package.json' },
    files = { 'src/app/app.component.ts', 'src/app/app.component.html' },
  },
  {
    name = 'monorepo',
    markers = { 'x18n.config.ts', 'x18n.config.yml', 'x18n.config.json' },
    -- web first: its file roots the client at the monorepo, which also owns
    -- the docs project; the docs file then reuses that client.
    files = { 'apps/web/src/App.vue', 'apps/docs/src/index.ts' },
  },
  {
    name = 'i18n-ally',
    markers = { 'package.json' },
    files = { 'src/App.vue' },
  },
}
