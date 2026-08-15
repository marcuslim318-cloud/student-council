<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { authState, isAdmin, isApprover, getReceiptUrl } from '../lib/auth'
import { money, fmtDate, fmtDateShort, CATEGORIES, statusName } from '../lib/utils'

const route = useRoute()
const router = useRouter()
const claim = ref(null)
const submitter = ref(null)
const receiptUrl = ref('')
const loading = ref(true)
const error = ref('')
const rejectReason = ref('')
const showReject = ref(false)
const busy = ref(false)

const canEdit = computed(
  () => claim.value?.submitter_id === authState.user.id && claim.value?.status === 'submitted'
)
const canApprove = computed(
  () =>
    isApprover.value &&
    claim.value?.status === 'submitted' &&
    claim.value?.submitter_id !== authState.user.id
)
const canPay = computed(
  () =>
    isApprover.value &&
    claim.value?.status === 'approved' &&
    claim.value?.submitter_id !== authState.user.id
)
const canDelete = computed(
  () => isAdmin.value
)

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('claims')
    .select('*')
    .eq('id', route.params.id)
    .maybeSingle()
  claim.value = data
  if (!data) {
    error.value = '报销单不存在'
    loading.value = false
    return
  }
  const { data: sub } = await supabase
    .from('profiles')
    .select('name, student_id')
    .eq('id', data.submitter_id)
    .maybeSingle()
  submitter.value = sub
  receiptUrl.value = await getReceiptUrl(data.receipt_path)
  loading.value = false
}

async function act(status, extra = {}) {
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
    patch.reject_reason = extra.reason || ''
  }
  const { error: err } = await supabase.from('claims').update(patch).eq('id', claim.value.id)
  if (err) {
    error.value = err.message
  } else {
    await load()
  }
  busy.value = false
}

async function remove() {
  if (!confirm('确定删除这条报销记录吗？删除会留下审计日志。')) return
  busy.value = true
  const { error: err } = await supabase.from('claims').delete().eq('id', claim.value.id)
  busy.value = false
  if (err) {
    error.value = err.message
  } else {
    router.push('/')
  }
}

onMounted(load)
</script>

<template>
  <div style="max-width: 640px">
    <div v-if="loading" class="loading">加载中…</div>
    <div v-else-if="error && !claim" class="empty">{{ error }}</div>

    <template v-else-if="claim">
      <div class="page-head">
        <div>
          <div class="page-title">{{ claim.title }}</div>
          <div class="page-sub">
            提交人：{{ submitter?.name || '—' }}（{{ submitter?.student_id || '—' }}）· {{ fmtDate(claim.created_at) }}
          </div>
        </div>
        <span class="badge" :class="claim.status">{{ statusName(claim.status) }}</span>
      </div>

      <div v-if="error" class="alert error">{{ error }}</div>

      <div class="card mb16">
        <div class="card-title">报销信息</div>
        <div class="detail-grid">
          <div class="detail-item"><div class="k">金额</div><div class="v" style="font-size:20px">{{ money(claim.amount) }}</div></div>
          <div class="detail-item"><div class="k">科目分类</div><div class="v">{{ claim.category }}</div></div>
          <div class="detail-item"><div class="k">发票号</div><div class="v">{{ claim.invoice_no || '—' }}</div></div>
          <div class="detail-item"><div class="k">当前状态</div><div class="v">{{ statusName(claim.status) }}</div></div>
          <div class="detail-item" v-if="claim.reason"><div class="k">补充说明</div><div class="v">{{ claim.reason }}</div></div>
          <div class="detail-item" v-if="claim.reject_reason"><div class="k">驳回原因</div><div class="v" style="color:var(--red)">{{ claim.reject_reason }}</div></div>
        </div>
        <div v-if="receiptUrl" class="mt16">
          <div class="k" style="font-size:12px;color:var(--text-2)">发票凭证</div>
          <a :href="receiptUrl" target="_blank"><img :src="receiptUrl" class="receipt-img" alt="发票" /></a>
        </div>
      </div>

      <div class="card mb16">
        <div class="card-title">审批进度</div>
        <div class="timeline">
          <div class="tl-item done">
            <div class="tl-title">已提交</div>
            <div class="tl-time">{{ fmtDate(claim.created_at) }} · 由 {{ submitter?.name || '本人' }} 提交</div>
          </div>
          <div class="tl-item" :class="claim.status === 'rejected' ? 'done' : (claim.approved_at ? 'done' : 'pending')">
            <div class="tl-title">
              {{ claim.status === 'rejected' ? '已驳回' : '审核通过' }}
            </div>
            <div class="tl-time">
              <template v-if="claim.status === 'rejected'">
                {{ claim.reject_reason ? '原因：' + claim.reject_reason + ' · ' : '' }}{{ claim.approved_at ? fmtDate(claim.approved_at) : fmtDate(claim.updated_at) }}
              </template>
              <template v-else>{{ claim.approved_at ? fmtDate(claim.approved_at) : '等待财政/管理员审核' }}</template>
            </div>
          </div>
          <div class="tl-item" :class="claim.paid_at ? 'done' : 'pending'">
            <div class="tl-title">已打款</div>
            <div class="tl-time">{{ claim.paid_at ? fmtDate(claim.paid_at) : '通过后由财政打款' }}</div>
          </div>
        </div>
      </div>

      <div v-if="canApprove || canPay || canEdit || canDelete" class="card">
        <div class="card-title">操作</div>

        <div v-if="canApprove" class="mt8">
          <div class="grow" style="display:flex;gap:8px;flex-wrap:wrap">
            <button class="btn success" :disabled="busy" @click="act('approved')">✓ 审核通过</button>
            <button class="btn danger" :disabled="busy" @click="showReject = !showReject">✗ 驳回</button>
          </div>
          <div v-if="showReject" class="mt8">
            <textarea v-model="rejectReason" placeholder="驳回原因（必填）" style="width:100%"></textarea>
            <button class="btn danger mt8" :disabled="busy || !rejectReason.trim()" @click="act('rejected', { reason: rejectReason.trim() })">确认驳回</button>
          </div>
        </div>

        <div v-if="canPay" class="mt8">
          <button class="btn success" :disabled="busy" @click="act('paid')">💰 确认已打款</button>
        </div>

        <div v-if="canEdit" class="mt8">
          <RouterLink :to="`/claims/${claim.id}/edit`" class="btn sm">修改报销单</RouterLink>
        </div>

        <div v-if="canDelete" class="mt8">
          <button class="btn danger sm" :disabled="busy" @click="remove">🗑 删除此报销单</button>
        </div>
      </div>
    </template>
  </div>
</template>