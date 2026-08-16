import { createRouter, createWebHistory } from 'vue-router'
import { supabase } from '../lib/supabase'
import { authState, isLoggedIn, isAdmin, isApprover, loadSession } from '../lib/auth'

const routes = [
  {
    path: '/login',
    name: 'login',
    component: () => import('../views/LoginView.vue'),
    meta: { public: true },
  },
  {
    path: '/register',
    name: 'register',
    component: () => import('../views/RegisterView.vue'),
    meta: { public: true },
  },
  {
    path: '/forgot-password',
    name: 'forgot',
    component: () => import('../views/ForgotPasswordView.vue'),
    meta: { public: true },
  },
  {
    path: '/reset-password',
    name: 'reset-password',
    component: () => import('../views/ResetPasswordView.vue'),
    meta: { public: true },
  },
  {
    path: '/',
    name: 'home',
    component: () => import('../views/HomeView.vue'),
  },
  {
    path: '/claims/new',
    name: 'new-claim',
    component: () => import('../views/NewClaimView.vue'),
  },
  {
    path: '/my-claims',
    name: 'my-claims',
    component: () => import('../views/MyClaimsView.vue'),
  },
  {
    path: '/claims/:id',
    name: 'claim-detail',
    component: () => import('../views/ClaimDetailView.vue'),
  },
  {
    path: '/claims/:id/edit',
    name: 'claim-edit',
    component: () => import('../views/EditClaimView.vue'),
  },
  {
    path: '/ledger',
    name: 'ledger',
    component: () => import('../views/LedgerView.vue'),
  },
  {
    path: '/approve',
    name: 'approve',
    component: () => import('../views/ApproveView.vue'),
    meta: { approver: true },
  },
  {
    path: '/admin',
    name: 'admin',
    component: () => import('../views/AdminView.vue'),
    meta: { admin: true },
  },
  {
    path: '/settings',
    name: 'settings',
    component: () => import('../views/SettingsView.vue'),
  },
  { path: '/:pathMatch(.*)*', redirect: '/' },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

router.beforeEach(async (to) => {
  if (!authState.user) {
    const session = await supabaseSession()
    if (session) await loadSession()
  }

  if (to.meta.public) {
    // 已登录用户访问登录页 → 回首页
    if (isLoggedIn.value && to.name === 'login') return { name: 'home' }
    return true
  }

  if (!isLoggedIn.value) return { name: 'login', query: { redirect: to.fullPath } }

  // 首次登录强制改密
  if (authState.profile?.must_change_password && to.name !== 'settings') {
    return { name: 'settings', query: { force: '1' } }
  }

  if (to.meta.admin && !isAdmin.value) return { name: 'home' }
  if (to.meta.approver && !isApprover.value) return { name: 'home' }

  return true
})

// 轻量会话探测，避免循环依赖
async function supabaseSession() {
  const { data } = await supabase.auth.getSession()
  return data?.session?.user ?? null
}

export default router