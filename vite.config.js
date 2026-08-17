import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue()],
  build: {
    rolldownOptions: {
      output: {
        codeSplitting: {
          groups: [
            { name: 'vue-vendor', test: /node_modules[\\/]vue|vue-router/ },
            { name: 'supabase', test: /node_modules[\\/]@supabase/ },
            { name: 'gsap', test: /node_modules[\\/]gsap/ },
            { name: 'excel', test: /node_modules[\\/]exceljs/ },
          ],
        },
      },
    },
  },
})
