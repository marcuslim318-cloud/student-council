<script setup>
import { computed } from 'vue'
import { authState, isLoggedIn } from './lib/auth'
</script>

<template>
  <RouterView v-if="!isLoggedIn" />
  <div v-else class="app-shell">
    <nav class="navbar">
      <div class="navbar-inner">
        <span class="brand">学生会<span class="accent">报销</span> <small>记账系统</small></span>
        <div class="nav-links">
          <RouterLink to="/home">首页</RouterLink>
          <RouterLink to="/my-claims">报销记录</RouterLink>
          <RouterLink to="/claims/new">提交报销</RouterLink>
          <RouterLink to="/ledger">公开账本</RouterLink>
          <RouterLink v-if="authState.profile?.role === 'admin' || authState.profile?.role === 'finance'" to="/approve">审核</RouterLink>
          <RouterLink v-if="authState.profile?.role === 'admin'" to="/admin">管理</RouterLink>
          <RouterLink to="/settings">设置</RouterLink>
        </div>
        <div class="nav-user">
          <span class="role-chip" :class="authState.profile?.role">{{ authState.profile?.role === 'admin' ? '管理员' : authState.profile?.role === 'finance' ? '财政' : '执委' }}</span>
          <span class="status-chip" :class="authState.profile?.status">{{ authState.profile?.status === 'active' ? '已通过' : authState.profile?.status === 'pending' ? '待审核' : '已禁用' }}</span>
          <span class="avatar">{{ (authState.profile?.name || '?').slice(0, 1) }}</span>
          <span class="nav-user-name">{{ authState.profile?.name || '用户' }}</span>
        </div>
      </div>
    </nav>
    <main class="container">
      <RouterView />
    </main>
  </div>
</template>

<script>
export default { name: 'App' }
</script>