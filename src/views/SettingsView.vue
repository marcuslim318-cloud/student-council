<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { authState, updatePassword, updateMyName, logout } from '../lib/auth'

const route = useRoute()
const forceChange = route.query.force === '1'

const name = ref('')
const newPass = ref('')
const confirmPass = ref('')
const error = ref('')
const success = ref('')
const busy = ref(false)

onMounted(() => {
  name.value = authState.profile?.name || ''
})

async function saveName() {
  error.value = ''
  success.value = ''
  if (!name.value.trim()) {
    error.value = '姓名不能为空'
    return
  }
  try {
    await updateMyName(name.value.trim())
    success.value = '姓名已更新'
  } catch (e) {
    error.value = e.message
  }
}

async function changePass() {
  error.value = ''
  success.value = ''
  if (newPass.value.length < 6) {
    error.value = '新密码至少 6 位'
    return
  }
  if (newPass.value !== confirmPass.value) {
    error.value = '两次输入的新密码不一致'
    return
  }
  busy.value = true
  try {
    await updatePassword(newPass.value)
    success.value = '密码已修改'
    newPass.value = ''
    confirmPass.value = ''
  } catch (e) {
    error.value = e.message
  } finally {
    busy.value = false
  }
}

async function doLogout() {
  await logout()
  window.location.href = '/login'
}
</script>

<template>
  <div style="max-width: 560px">
    <div class="page-head">
      <div>
        <div class="page-title">设置</div>
        <div class="page-sub" v-if="forceChange">⚠️ 首次登录，请先修改初始密码后再使用系统</div>
      </div>
    </div>

    <div v-if="error" class="alert error">{{ error }}</div>
    <div v-if="success" class="alert success">{{ success }}</div>

    <div class="card mb16">
      <div class="card-title">个人资料</div>
      <div class="field">
        <label>姓名</label>
        <input v-model="name" />
      </div>
      <div class="field">
        <label>学号</label>
        <input :value="authState.profile?.student_id" disabled />
      </div>
      <div class="field">
        <label>邮箱</label>
        <input :value="authState.user?.email" disabled />
      </div>
      <button class="btn" @click="saveName">保存姓名</button>
    </div>

    <div class="card mb16">
      <div class="card-title">修改密码</div>
      <div class="field">
        <label>新密码</label>
        <input v-model="newPass" type="password" placeholder="至少 6 位" />
      </div>
      <div class="field">
        <label>确认新密码</label>
        <input v-model="confirmPass" type="password" placeholder="再输入一次" />
      </div>
      <button class="btn primary" :disabled="busy" @click="changePass">
        {{ forceChange ? '保存并开始使用' : '修改密码' }}
      </button>
    </div>

    <div class="card">
      <div class="card-title">账号</div>
      <button class="btn danger" @click="doLogout">退出登录</button>
    </div>
  </div>
</template>