<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { getReceiptUrl } from '../lib/auth'
import { money, fmtDateShort, statusName } from '../lib/utils'

// 导出库体积大，按需动态加载
const exportExcel = async () => {
  const { default: XLSX } = await import('xlsx')
  const rows = exportRows()
  const ws = XLSX.utils.json_to_sheet(rows)
  ws['!cols'] = [{ wch: 6 }, { wch: 10 }, { wch: 10 }, { wch: 12 }, { wch: 24 }, { wch: 10 }, { wch: 10 }, { wch: 14 }, { wch: 8 }, { wch: 12 }]
  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, '报销账本')
  XLSX.writeFile(wb, `报销账本_${new Date().toISOString().slice(0, 10)}.xlsx`)
}

const claims = ref([])
const profilesMap = ref({})
const loading = ref(true)
const tab = ref('all')
const receiptUrls = ref({})

const filtered = computed(() => {
  if (tab.value === 'all') return claims.value
  return claims.value.filter((c) => c.status === tab.value)
})

const summary = computed(() => {
  const paid = claims.value.filter((c) => c.status === 'paid')
  const approved = claims.value.filter((c) => c.status === 'approved')
  const pending = claims.value.filter((c) => c.status === 'submitted')
  const totalPaid = paid.reduce((s, c) => s + Number(c.amount), 0)
  const totalApproved = approved.reduce((s, c) => s + Number(c.amount), 0)
  const totalPending = pending.reduce((s, c) => s + Number(c.amount), 0)
  return {
    count: claims.value.length,
    paidCount: paid.length,
    paidAmount: totalPaid,
    approvedAmount: totalApproved + totalPaid,
    pendingAmount: totalPending,
    byCat: categorySummary(),
    byPerson: personSummary(),
  }
})

function categorySummary() {
  const m = {}
  claims.value
    .filter((c) => c.status === 'paid' || c.status === 'approved')
    .forEach((c) => {
      m[c.category] = (m[c.category] || 0) + Number(c.amount)
    })
  return Object.entries(m).sort((a, b) => b[1] - a[1])
}

function personSummary() {
  const m = {}
  claims.value
    .filter((c) => c.status === 'paid' || c.status === 'approved')
    .forEach((c) => {
      const name = profilesMap.value[c.submitter_id]?.name || '未知'
      m[name] = (m[name] || 0) + Number(c.amount)
    })
  return Object.entries(m).sort((a, b) => b[1] - a[1])
}

async function load() {
  loading.value = true
  const [cRes, pRes] = await Promise.all([
    supabase.from('claims').select('*').order('created_at', { ascending: false }),
    supabase.from('profiles').select('id, name, student_id, position'),
  ])
  claims.value = cRes.data || []
  const map = {}
  ;(pRes.data || []).forEach((p) => (map[p.id] = p))
  profilesMap.value = map
  loading.value = false
}

async function viewReceipt(claim) {
  if (!claim.receipt_path) return
  const url = await getReceiptUrl(claim.receipt_path)
  window.open(url, '_blank')
}

function exportRows() {
  return claims.value.map((c, i) => ({
    序号: i + 1,
    提交人: profilesMap.value[c.submitter_id]?.name || '—',
    职位: profilesMap.value[c.submitter_id]?.position || '—',
    学号: profilesMap.value[c.submitter_id]?.student_id || '—',
    事由: c.title,
    科目: c.category,
    金额: Number(c.amount),
    发票号: c.invoice_no || '',
    状态: statusName(c.status),
    提交时间: fmtDateShort(c.created_at),
  }))
}

onMounted(load)
</script>

<template>
  <div>
    <div class="page-head">
      <div>
        <div class="page-title">公开账本</div>
        <div class="page-sub">全员可见 · 实时更新 · 已打款记录计入支出</div>
      </div>
      <div style="display:flex;gap:8px">
        <button class="btn" @click="exportExcel">⬇ 导出 Excel</button>
      </div>
    </div>

    <div v-if="loading" class="loading">加载中…</div>
    <template v-else>
      <div class="kpi-row mb16">
        <div class="kpi"><div class="v" style="color:var(--green)">{{ money(summary.paidAmount) }}</div><div class="l">已打款支出（{{ summary.paidCount }} 笔）</div></div>
        <div class="kpi"><div class="v" style="color:var(--primary)">{{ money(summary.approvedAmount) }}</div><div class="l">已通过（含待打款）</div></div>
        <div class="kpi"><div class="v" style="color:var(--amber)">{{ money(summary.pendingAmount) }}</div><div class="l">待审核</div></div>
        <div class="kpi"><div class="v">{{ summary.count }}</div><div class="l">报销单总数</div></div>
      </div>

      <div class="grid grid-2 mb16">
        <div class="card">
          <div class="card-title">按科目支出 <span class="sub">（已通过+已打款）</span></div>
          <table class="data">
            <tr><th>科目</th><th>金额</th></tr>
            <tr v-for="[k, v] in summary.byCat" :key="k"><td>{{ k }}</td><td>{{ money(v) }}</td></tr>
            <tr v-if="!summary.byCat.length"><td colspan="2" class="muted">暂无数据</td></tr>
          </table>
        </div>
        <div class="card">
          <div class="card-title">按成员支出</div>
          <table class="data">
            <tr><th>成员</th><th>金额</th></tr>
            <tr v-for="[k, v] in summary.byPerson" :key="k"><td>{{ k }}</td><td>{{ money(v) }}</td></tr>
            <tr v-if="!summary.byPerson.length"><td colspan="2" class="muted">暂无数据</td></tr>
          </table>
        </div>
      </div>

      <div class="tabs">
        <button :class="{ active: tab === 'all' }" @click="tab = 'all'">全部</button>
        <button :class="{ active: tab === 'submitted' }" @click="tab = 'submitted'">待审核</button>
        <button :class="{ active: tab === 'approved' }" @click="tab = 'approved'">已通过</button>
        <button :class="{ active: tab === 'paid' }" @click="tab = 'paid'">已打款</button>
        <button :class="{ active: tab === 'rejected' }" @click="tab = 'rejected'">已驳回</button>
      </div>

      <div v-if="!filtered.length" class="empty">暂无记录</div>
      <div v-else class="grid">
        <RouterLink v-for="c in filtered" :key="c.id" :to="`/claims/${c.id}`" class="list-item">
          <div>
            <div class="title">{{ c.title }}</div>
            <div class="meta">
              <span>{{ statusName(c.status) }}</span>
              <span>{{ profilesMap[c.submitter_id]?.name || '—' }}<template v-if="profilesMap[c.submitter_id]?.position">（{{ profilesMap[c.submitter_id].position }}）</template></span>
              <span>{{ c.category }}</span>
              <span>{{ fmtDateShort(c.created_at) }}</span>
            </div>
          </div>
          <div style="text-align:right">
            <div class="amount" :class="c.status">{{ money(c.amount) }}</div>
            <button v-if="c.receipt_path" class="btn sm mt8" @click.prevent="viewReceipt(c)">🧾 看发票</button>
          </div>
        </RouterLink>
      </div>
    </template>
  </div>
</template>