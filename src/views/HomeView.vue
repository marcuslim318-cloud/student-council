<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { authState, profileStatus, isApprover } from '../lib/auth'
import { money, fmtDate, statusName } from '../lib/utils'

const myClaims = ref([])
const loading = ref(true)
const stats = ref({ total: 0, pending: 0, approved: 0, paid: 0, rejected: 0 })

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('claims')
    .select('*')
    .eq('submitter_id', authState.user.id)
    .order('created_at', { ascending: false })
  myClaims.value = data || []
  stats.value = {
    total: myClaims.value.length,
    pending: myClaims.value.filter((c) => c.status === 'submitted').length,
    approved: myClaims.value.filter((c) => c.status === 'approved').length,
    paid: myClaims.value.filter((c) => c.status === 'paid').length,
    rejected: myClaims.value.filter((c) => c.status === 'rejected').length,
  }
  loading.value = false
}

onMounted(load)
</script>

<template>
  <div>
    <div class="page-head">
      <div>
        <div class="page-title">你好，{{ authState.profile?.name }}</div>
        <div class="page-sub" v-if="profileStatus !== 'active'">
          <span v-if="profileStatus === 'pending'">⚠️ 账号待管理员审核，审核通过后才能提交报销</span>
          <span v-else>⛔ 账号已被禁用，请联系管理员</span>
        </div>
        <div class="page-sub" v-else>在这里提交报销单，财务审批后将自动公开到账本</div>
      </div>
      <RouterLink to="/claims/new" class="btn primary">+ 提交报销</RouterLink>
    </div>

    <div class="kpi-row mb16">
      <div class="kpi"><div class="v">{{ stats.total }}</div><div class="l">我的报销单</div></div>
      <div class="kpi"><div class="v" style="color:var(--amber)">{{ stats.pending }}</div><div class="l">待审核</div></div>
      <div class="kpi"><div class="v" style="color:var(--primary)">{{ stats.approved }}</div><div class="l">已通过</div></div>
      <div class="kpi"><div class="v" style="color:var(--green)">{{ stats.paid }}</div><div class="l">已打款</div></div>
    </div>

    <div class="card-title">我的报销记录</div>
    <div v-if="loading" class="loading">加载中…</div>
    <div v-else-if="!myClaims.length" class="empty">还没有报销记录，点击「提交报销」开始</div>
    <div v-else class="grid">
      <RouterLink v-for="c in myClaims" :key="c.id" :to="`/claims/${c.id}`" class="list-item">
        <div>
          <div class="title">{{ c.title }}</div>
          <div class="meta">
            <span>{{ statusName(c.status) }}</span>
            <span>{{ c.category }}</span>
            <span>{{ fmtDate(c.created_at) }}</span>
          </div>
        </div>
        <span class="amount" :class="c.status">{{ money(c.amount) }}</span>
      </RouterLink>
    </div>
  </div>
</template>