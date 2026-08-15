<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { authState, isAdmin, getReceiptUrl } from '../lib/auth'
import { money, fmtDate, statusName } from '../lib/utils'

const tab = ref('submitted')
const claims = ref([])
const profilesMap = ref({})
const receiptUrls = ref({})
const loading = ref(true)
const rejectReason = ref('')
const showRejectFor = ref(null)
const busy = ref(false)

const filtered = computed(() => claims.value.filter((c) => c.status === tab.value))

async function load() {
  loading.value = true
  const [cRes, pRes] = await Promise.all([
    supabase.from('claims').select('*').order('created_at', { ascending: true }),
    supabase.from('profiles').select('id, name, student_id, position'),
  ])
  claims.value = cRes.data || []
  const map = {}
  ;(pRes.data || []).forEach((p) => (map[p.id] = p))
  profilesMap.value = map
  // 预取所有有发票的收据 URL
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

function subName(c) {
  const p = profilesMap.value[c.submitter_id]
  return p ? `${p.name}（${p.position || '未填职位'}）` : '—'
}

async function act(claim, status) {
  busy.value = true
  const patch = { status }
  if (status === 'approved') {
    patch.approved_by = authState.user.id
    patch.approved_at = new Date().toISOString()
    patch.reject_reason = ''
  } else if (status === 'paid') {
    patch.paid_by = authState.user.id
    patch.paid_at = new Date().toISOString()
  } else if (status === 'rejected') {
    if (!rejectReason.value.trim()) {
      busy.value = false
      return
    }
    patch.reject_reason = rejectReason.value.trim()
  }
  const { error } = await supabase.from('claims').update(patch).eq('id', claim.id)
  if (error) alert('操作失败：' + error.message)
  showRejectFor.value = null
  rejectReason.value = ''
  busy.value = false
  await load()
}

onMounted(load)
</script>

<template>
  <div>
    <div class="page-head">
      <div>
        <div class="page-title">审批工作台</div>
        <div class="page-sub">管理员可审核自己的单据 · 财政不能审核自己 · 所有操作自动记录审计日志</div>
      </div>
    </div>

    <div class="tabs">
      <button :class="{ active: tab === 'submitted' }" @click="tab = 'submitted'">待审核</button>
      <button :class="{ active: tab === 'approved' }" @click="tab = 'approved'">已通过待打款</button>
      <button :class="{ active: tab === 'paid' }" @click="tab = 'paid'">已打款</button>
      <button :class="{ active: tab === 'rejected' }" @click="tab = 'rejected'">已驳回</button>
    </div>

    <div v-if="loading" class="loading">加载中…</div>
    <div v-else-if="!filtered.length" class="empty">该列表暂无单据</div>
    <div v-else class="grid">
      <div v-for="c in filtered" :key="c.id" class="card">
        <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:8px">
          <div>
            <div style="font-weight:600">{{ c.title }}</div>
            <div class="meta muted" style="font-size:12px;margin-top:4px">
              {{ subName(c) }} · {{ fmtDate(c.created_at) }}
            </div>
          </div>
          <div style="text-align:right">
            <div style="font-size:18px;font-weight:700">{{ money(c.amount) }}</div>
            <div class="badge" :class="c.status" style="margin-top:4px">{{ statusName(c.status) }}</div>
          </div>
        </div>
        <div v-if="c.receipt_path" class="mt8">
          <div class="small muted mb16" style="margin-bottom:6px">收据凭证：</div>
          <a :href="receiptUrls[c.id]" target="_blank" rel="noopener">
            <img
              :src="receiptUrls[c.id]"
              :alt="c.title"
              loading="lazy"
              style="max-width:100%;max-height:200px;border-radius:8px;border:1px solid var(--border);display:block"
            />
          </a>
        </div>
        <div class="mt8 muted small">
          <span>{{ c.category }}</span>
          <span v-if="c.invoice_no"> · 发票号：{{ c.invoice_no }}</span>
        </div>
        <div v-if="c.reason" class="mt8 small">{{ c.reason }}</div>
        <div v-if="c.reject_reason" class="mt8 small" style="color:var(--red)">驳回原因：{{ c.reject_reason }}</div>
        <div v-if="c.approved_at" class="mt8 small muted">已通过：{{ fmtDate(c.approved_at) }}</div>
        <div v-if="c.paid_at" class="mt8 small muted">已打款：{{ fmtDate(c.paid_at) }}</div>

        <div style="display:flex;gap:6px;flex-wrap:wrap;margin-top:12px">
          <RouterLink class="btn sm" :to="`/claims/${c.id}`">详情</RouterLink>
          <template v-if="c.status === 'submitted' && (isAdmin || c.submitter_id !== authState.user.id)">
            <button class="btn sm success" :disabled="busy" @click="act(c, 'approved')">✓ 通过</button>
            <button class="btn sm danger" :disabled="busy" @click="showRejectFor = showRejectFor === c.id ? null : c.id">✗ 驳回</button>
          </template>
          <button v-if="c.status === 'approved' && (isAdmin || c.submitter_id !== authState.user.id)" class="btn sm success" :disabled="busy" @click="act(c, 'paid')">💰 打款</button>
        </div>

        <div v-if="showRejectFor === c.id" class="mt8" style="display:flex;gap:6px">
          <input v-model="rejectReason" placeholder="驳回原因" style="flex:1;padding:6px 10px;border:1px solid var(--border);border-radius:8px" />
          <button class="btn sm danger" :disabled="busy || !rejectReason.trim()" @click="act(c, 'rejected')">确认</button>
        </div>
      </div>
    </div>
  </div>
</template>