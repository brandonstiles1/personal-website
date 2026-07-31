import { defineConfig } from 'astro/config'
import sitemap from '@astrojs/sitemap'

export default defineConfig({
    site: 'https://brandonstiles.com',
    base: '/',
    integrations: [sitemap()],
})
