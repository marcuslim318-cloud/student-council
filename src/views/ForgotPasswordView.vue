<script setup>
import { ref } from 'vue'
import { resetPassword } from '../lib/auth'

const email = ref('')
const error = ref('')
const success = ref('')
const loading = ref(false)

async function submit() {
  error.value = ''
  success.value = ''
  if (!email.value.trim()) {
    error.value = '请输入注册邮箱'
    return
  }
  loading.value = true
  try {
    await resetPassword(email.value.trim())
    success.value = '已发送重置邮件，请查收邮箱并按链接操作'
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
        <div class="big">找回密码</div>
        <div class="en">向注册邮箱发送重置链接</div>
      </div>
      <div class="card">
        <div class="field">
          <label>注册邮箱</label>
          <input v-model="email" type="email" placeholder="example@mail.com" @keyup.enter="submit" />
        </div>
        <div v-if="error" class="alert error">{{ error }}</div>
        <div v-if="success" class="alert success">{{ success }}</div>
        <button class="btn primary block" :disabled="loading" @click="submit">
          {{ loading ? '发送中…' : '发送重置邮件' }}
        </button>
        <div class="auth-tip"><RouterLink to="/login">返回登录</RouterLink></div>
      </div>
    </div>
  </div>
</template>