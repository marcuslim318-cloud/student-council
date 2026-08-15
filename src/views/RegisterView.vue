<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { registerWithStudentId } from '../lib/auth'

const router = useRouter()

const form = ref({ studentId: '', name: '', email: '', password: '', password2: '' })
const error = ref('')
const success = ref('')
const loading = ref(false)

async function submit() {
  error.value = ''
  success.value = ''
  const { studentId, name, email, password, password2 } = form.value
  if (!studentId.trim() || !name.trim() || !email.trim() || !password) {
    error.value = '请填写完整信息'
    return
  }
  if (password.length < 6) {
    error.value = '密码至少 6 位'
    return
  }
  if (password !== password2) {
    error.value = '两次输入的密码不一致'
    return
  }
  loading.value = true
  try {
    await registerWithStudentId({
      studentId: studentId.trim(),
      name: name.trim(),
      email: email.trim(),
      password,
    })
    success.value = '注册成功！请先到邮箱点击确认链接激活账号，然后等待管理员审核通过即可提交报销。'
    setTimeout(() => router.push('/login'), 3500)
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
        <div class="big">注册执委账号</div>
        <div class="en">注册 → 邮箱确认 → 管理员审核，通过后才能提交报销</div>
      </div>
      <div class="card">
        <div class="field">
          <label>学号（登录账号）</label>
          <input v-model="form.studentId" placeholder="你的学号，作为登录账号" />
        </div>
        <div class="field">
          <label>姓名</label>
          <input v-model="form.name" placeholder="真实姓名" />
        </div>
        <div class="field">
          <label>邮箱（用于找回密码）</label>
          <input v-model="form.email" type="email" placeholder="example@mail.com" />
        </div>
        <div class="field">
          <label>密码</label>
          <input v-model="form.password" type="password" placeholder="至少 6 位" />
        </div>
        <div class="field">
          <label>确认密码</label>
          <input v-model="form.password2" type="password" placeholder="再输入一次" />
        </div>
        <div v-if="error" class="alert error">{{ error }}</div>
        <div v-if="success" class="alert success">{{ success }}</div>
        <button class="btn primary block" :disabled="loading" @click="submit">
          <span v-if="loading" class="spinner"></span>
          {{ loading ? '注册中…' : '注 册' }}
        </button>
        <div class="auth-tip">已有账号？<RouterLink to="/login">返回登录</RouterLink></div>
      </div>
    </div>
  </div>
</template>