<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { updatePassword } from '../lib/auth'

const router = useRouter()
const p1 = ref('')
const p2 = ref('')
const error = ref('')
const loading = ref(false)

async function submit() {
  error.value = ''
  if (p1.value.length < 6) {
    error.value = '密码至少 6 位'
    return
  }
  if (p1.value !== p2.value) {
    error.value = '两次输入的密码不一致'
    return
  }
  loading.value = true
  try {
    await updatePassword(p1.value)
    router.push('/home')
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="auth-wrap">
    <div class="auth-card">
      <div class="auth-logo">
        <div class="big">设置新密码</div>
      </div>
      <div class="card">
        <div class="field">
          <label>新密码</label>
          <input v-model="p1" type="password" placeholder="至少 6 位" />
        </div>
        <div class="field">
          <label>确认新密码</label>
          <input v-model="p2" type="password" placeholder="再输入一次" />
        </div>
        <div v-if="error" class="alert error">{{ error }}</div>
        <button class="btn primary block" :disabled="loading" @click="submit">
          {{ loading ? '保存中…' : '保存新密码' }}
        </button>
      </div>
    </div>
  </div>
</template>