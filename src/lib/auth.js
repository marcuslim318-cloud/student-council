import { reactive, computed } from 'vue'
import { supabase } from './supabase'

// 全局登录态 + 用户档案
export const authState = reactive({
  user: null,      // supabase auth 用户
  profile: null,   // profiles 表记录
  loading: true,
})

export const isLoggedIn = computed(() => !!authState.user)
export const role = computed(() => authState.profile?.role || 'member')
export const isAdmin = computed(() => role.value === 'admin')
export const isFinance = computed(() => role.value === 'finance')
export const isApprover = computed(() => isAdmin.value || isFinance.value)
export const profileStatus = computed(() => authState.profile?.status || 'pending')

export async function loadSession() {
  const { data } = await supabase.auth.getSession()
  authState.user = data?.session?.user ?? null
  if (authState.user) {
    await loadProfile()
  }
  authState.loading = false
}

export async function loadProfile() {
  if (!authState.user) return null
  const { data } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', authState.user.id)
    .maybeSingle()
  authState.profile = data
  return data
}

// 用学号找对应用户的 email（登录用，安全函数绕过 RLS）
async function emailByStudentId(studentId) {
  const { data } = await supabase.rpc('get_email_by_student_id', { p_student_id: studentId })
  return data || null
}

// 登录前检查是否被限速
export async function checkLoginAllowed(studentId) {
  const { data, error } = await supabase.rpc('check_login_allowed', { p_identifier: studentId })
  if (error) return { allowed: true } // 函数不可用时放行，避免误锁
  return data || { allowed: true }
}

export async function recordLoginAttempt(studentId, success) {
  await supabase.rpc('record_login_attempt', {
    p_identifier: studentId,
    p_success: success,
  })
}

// 学号 + 密码登录
export async function loginWithStudentId(studentId, password) {
  const limit = await checkLoginAllowed(studentId)
  if (!limit.allowed) {
    throw new Error(limit.message || '尝试次数过多，请稍后再试')
  }

  const email = await emailByStudentId(studentId)
  if (!email) {
    await recordLoginAttempt(studentId, false)
    throw new Error('学号不存在，或账号尚未注册')
  }

  const { error } = await supabase.auth.signInWithPassword({ email, password })
  if (error) {
    await recordLoginAttempt(studentId, false)
    throw new Error('学号或密码错误')
  }

  await recordLoginAttempt(studentId, true)
  await loadProfile()
  return authState.profile
}

// 注册（学号唯一性由数据库保证；邮箱验证关闭时自动确认）
export async function registerWithStudentId({ studentId, name, email, password }) {
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: { student_id: studentId, name },
    },
  })
  if (error) throw new Error(error.message)
  return data
}

// 重置密码（发送邮件）
export async function resetPassword(email) {
  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: `${window.location.origin}/reset-password`,
  })
  if (error) throw new Error(error.message)
}

// 更新密码
export async function updatePassword(newPassword) {
  const { error } = await supabase.auth.updateUser({ password: newPassword })
  if (error) throw new Error(error.message)
  await supabase.rpc('finish_password_change')
  await loadProfile()
}

// 更新姓名（安全函数，只改 name 字段，防自提权）
export async function updateMyName(name) {
  const { error } = await supabase.rpc('update_my_name', { p_name: name })
  if (error) throw new Error(error.message)
  await loadProfile()
}

export async function logout() {
  await supabase.auth.signOut()
  authState.user = null
  authState.profile = null
}

// 获取可公开访问的发票 URL（私有桶签名 URL，有效一段时间）
export async function getReceiptUrl(path) {
  if (!path) return ''
  const { data } = await supabase.storage.from('receipts').createSignedUrl(path, 3600)
  return data?.signedUrl || ''
}