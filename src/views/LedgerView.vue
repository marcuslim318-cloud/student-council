<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { getReceiptUrl } from '../lib/auth'
import { money, fmtDateShort, statusName, categoryColor } from '../lib/utils'

// 导出 Excel：动态加载库 + 手动 Blob 下载（兼容性更好）
const exportExcel = async () => {
  if (!claims.value.length) {
    alert('当前没有可导出的报销记录')
    return
  }
  try {
    const mod = await import('xlsx')
    const XLSX = mod.default ?? mod
    const rows = exportRows()
    const ws = XLSX.utils.json_to_sheet(rows)
    ws['!cols'] = [{ wch: 6 }, { wch: 10 }, { wch: 10 }, { wch: 12 }, { wch: 24 }, { wch: 10 }, { wch: 10 }, { wch: 14 }, { wch: 8 }, { wch: 12 }]
    const wb = XLSX.utils.book_new()
    XLSX.utils.book_append_sheet(wb, ws, '报销账本')
    const out = XLSX.write(wb, { bookType: 'xlsx', type: 'array' })
    const blob = new Blob([out], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `报销账本_${new Date().toISOString().slice(0, 10)}.xlsx`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
  } catch (e) {
    alert('导出失败：' + (e?.message || e))
  }
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

// 科目占比（带百分比），用于色块条
const catShare = computed(() => {
  const byCat = categorySummary()
  const total = byCat.reduce((s, [, v]) => s + v, 0)
  if (!total) return []
  return byCat.map(([k, v]) => ({ name: k, amount: v, pct: Math.round((v / total) * 100) }))
})

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
          <div v-if="!catShare.length" class="muted" style="padding:8px 0">暂无数据</div>
          <template v-else>
            <div class="cat-bar" style="display:flex;height:18px;border-radius:6px;overflow:hidden;margin-bottom:12px">
              <div
                v-for="s in catShare"
                :key="s.name"
                :style="{ width: s.pct + '%', background: categoryColor(s.name) }"
                :title="`${s.name} ${s.pct}%`"
              ></div>
            </div>
            <div class="cat-legend" style="display:flex;flex-direction:column;gap:6px">
              <div v-for="s in catShare" :key="s.name" style="display:flex;align-items:center;gap:8px;font-size:13px">
                <span :style="{ width: '10px', height: '10px', borderRadius: '3px', background: categoryColor(s.name), flexShrink: 0 }"></span>
                <span style="flex:1">{{ s.name }}</span>
                <span style="color:var(--text-2)">{{ money(s.amount) }}</span>
                <span style="width:44px;text-align:right;color:var(--text-2)">{{ s.pct }}%</span>
              </div>
            </div>
          </template>
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