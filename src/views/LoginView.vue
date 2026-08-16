<script setup>
import { ref } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { loginWithStudentId } from '../lib/auth'

const router = useRouter()
const route = useRoute()

const studentId = ref('')
const password = ref('')
const error = ref('')
const loading = ref(false)

async function submit() {
  error.value = ''
  if (!studentId.value.trim() || !password.value) {
    error.value = '请输入学号和密码'
    return
  }
  loading.value = true
  try {
    await loginWithStudentId(studentId.value.trim(), password.value)
    const redirect = route.query.redirect || '/home'
    router.push(redirect)
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
        <div class="big">学生会报销记账系统</div>
        <div class="en">Reimbursement &amp; Ledger</div>
      </div>
      <div class="card">
        <div class="field">
          <label>学号</label>
          <input v-model="studentId" placeholder="请输入学号" @keyup.enter="submit" />
        </div>
        <div class="field">
          <label>密码</label>
          <input v-model="password" type="password" placeholder="请输入密码" @keyup.enter="submit" />
        </div>
        <div v-if="error" class="alert error">{{ error }}</div>
        <button class="btn cta block" :disabled="loading" @click="submit">
          <span v-if="loading" class="spinner"></span>
          {{ loading ? '登录中…' : '登 录' }}
        </button>
        <div class="auth-tip">
          <RouterLink to="/forgot-password">忘记密码？</RouterLink>
          ｜ 还没有账号？
          <RouterLink to="/register">注册</RouterLink>
        </div>
      </div>
      <div class="auth-tip">登录失败 5 次将锁定 15 分钟 · 发票图片仅本人、财政、管理员可见</div>
    </div>
  </div>
</template>