<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { CATEGORIES } from '../lib/utils'

const route = useRoute()
const router = useRouter()
const form = ref({ title: '', category: '其他', amount: '', invoiceNo: '', reason: '' })
const error = ref('')
const loading = ref(true)
const busy = ref(false)

onMounted(async () => {
  const { data } = await supabase
    .from('claims')
    .select('*')
    .eq('id', route.params.id)
    .maybeSingle()
  if (!data) {
    error.value = '报销单不存在'
    loading.value = false
    return
  }
  form.value = {
    title: data.title,
    category: data.category,
    amount: data.amount,
    invoiceNo: data.invoice_no,
    reason: data.reason,
  }
  loading.value = false
})

async function save() {
  error.value = ''
  if (!form.value.title.trim() || !form.value.amount || Number(form.value.amount) <= 0) {
    error.value = '请填写事由和有效金额'
    return
  }
  busy.value = true
  const { error: err } = await supabase
    .from('claims')
    .update({
      title: form.value.title.trim(),
      category: form.value.category,
      amount: Number(form.value.amount),
      invoice_no: form.value.invoiceNo.trim(),
      reason: form.value.reason.trim(),
    })
    .eq('id', route.params.id)
  busy.value = false
  if (err) {
    error.value = err.message
  } else {
    router.push(`/claims/${route.params.id}`)
  }
}
</script>

<template>
  <div style="max-width: 560px">
    <div class="page-head">
      <div>
        <div class="page-title">修改报销单</div>
        <div class="page-sub">仅待审核状态的报销单可修改</div>
      </div>
    </div>
    <div v-if="loading" class="loading">加载中…</div>
    <div class="card" v-else>
      <div class="field">
        <label>报销事由 *</label>
        <input v-model="form.title" />
      </div>
      <div class="form-row">
        <div class="field">
          <label>科目分类</label>
          <select v-model="form.category">
            <option v-for="c in CATEGORIES" :key="c" :value="c">{{ c }}</option>
          </select>
        </div>
        <div class="field">
          <label>金额（元）*</label>
          <input v-model="form.amount" type="number" step="0.01" min="0" />
        </div>
      </div>
      <div class="field">
        <label>发票号</label>
        <input v-model="form.invoiceNo" />
      </div>
      <div class="field">
        <label>补充说明</label>
        <textarea v-model="form.reason"></textarea>
      </div>
      <div v-if="error" class="alert error">{{ error }}</div>
      <div style="display:flex;gap:8px">
        <button class="btn primary grow" :disabled="busy" @click="save">保存</button>
        <RouterLink class="btn" :to="`/claims/${route.params.id}`">取消</RouterLink>
      </div>
    </div>
  </div>
</template>