<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { authState } from '../lib/auth'
import { money, fmtDate, statusName } from '../lib/utils'

const claims = ref([])
const loading = ref(true)

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('claims')
    .select('*')
    .eq('submitter_id', authState.user.id)
    .order('created_at', { ascending: false })
  claims.value = data || []
  loading.value = false
}

onMounted(load)
</script>

<template>
  <div>
    <div class="page-head">
      <div>
        <div class="page-title">我的报销记录</div>
        <div class="page-sub">共 {{ claims.length }} 条 · 点击查看详情与审批进度</div>
      </div>
      <RouterLink to="/claims/new" class="btn primary">+ 提交报销</RouterLink>
    </div>

    <div v-if="loading" class="loading">加载中…</div>
    <div v-else-if="!claims.length" class="empty">还没有报销记录，点击「提交报销」开始</div>
    <div v-else class="grid">
      <RouterLink v-for="c in claims" :key="c.id" :to="`/claims/${c.id}`" class="list-item">
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