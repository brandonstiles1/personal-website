// @ts-check
import { defineConfig } from 'astro/config';
import github from "@astrojs/github";


// https://astro.build/config
export default defineConfig({
    integrations: [github()],
    site: 'https://brandonstiles1.github.io/personal-website/'
});
