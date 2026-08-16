<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { money, fmtDateShort, statusName, categoryColor } from '../lib/utils'
import { getReceiptUrl } from '../lib/auth'

// 导出 Excel：用 exceljs 生成，支持嵌入发票照片
const exportExcel = async () => {
  if (!claims.value.length) {
    alert('当前没有可导出的报销记录')
    return
  }
  try {
    const ExcelJS = (await import('exceljs')).default
    const wb = new ExcelJS.Workbook()
    const ws = wb.addWorksheet('报销账本')

    ws.columns = [
      { header: '提交日期', key: 'date', width: 14 },
      { header: '提交人', key: 'name', width: 16 },
      { header: '事由', key: 'title', width: 28 },
      { header: '科目', key: 'category', width: 14 },
      { header: '金额(元)', key: 'amount', width: 12 },
      { header: '发票照片', key: 'receipt', width: 22 },
      { header: '状态', key: 'status', width: 12 },
    ]
    // 表头样式
    ws.getRow(1).font = { bold: true, color: { argb: 'FFFFFFFF' } }
    ws.getRow(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF2F6FED' } }
    ws.getRow(1).height = 22

    let rowNum = 2
    for (const c of claims.value) {
      const p = profilesMap.value[c.submitter_id]
      ws.addRow({
        date: fmtDateShort(c.created_at),
        name: p?.name || '—',
        title: c.title,
        category: c.category,
        amount: Number(c.amount),
        receipt: c.receipt_path ? '见下方图片' : '无照片',
        status: statusName(c.status),
      })
      ws.getCell(`E${rowNum}`).numFmt = '#,##0.00'
      // 嵌入发票照片
      if (c.receipt_path && receiptUrls.value[c.id]) {
        try {
          const resp = await fetch(receiptUrls.value[c.id])
          const buf = await resp.arrayBuffer()
          const ext = c.receipt_path.split('.').pop()?.toLowerCase() === 'png' ? 'png' : 'jpeg'
          const imgId = wb.addImage({ buffer: buf, extension: ext })
          ws.addImage(imgId, {
            tl: { col: 5, row: rowNum - 1 },
            ext: { width: 110, height: 82 },
            editAs: 'oneCell',
          })
          ws.getRow(rowNum).height = 64
        } catch {
          ws.getCell(`F${rowNum}`).value = '有照片(加载失败)'
        }
      }
      rowNum++
    }
    ws.views = [{ state: 'frozen', ySplit: 1 }]

    const out = await wb.xlsx.writeBuffer()
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
  // 预取发票照片 URL（用于 Excel 导出）
  const urlMap = {}
  await Promise.all(
    claims.value
      .filter((c) => c.receipt_path)
      .map(async (c) => {
        urlMap[c.id] = await getReceiptUrl(c.receipt_path)
      })
  )
  receiptUrls.value = urlMap
  loading.value = false
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
          </div>
        </RouterLink>
      </div>
    </template>
  </div>
</template>