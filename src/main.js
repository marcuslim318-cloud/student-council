import { createApp } from 'vue'
import './style.css'
import App from './App.vue'
import router from './router'
import { loadSession } from './lib/auth'

const app = createApp(App)
app.use(router)
app.mount('#app')

loadSession()