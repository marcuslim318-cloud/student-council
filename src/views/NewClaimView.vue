<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { authState, profileStatus } from '../lib/auth'
import { CATEGORIES } from '../lib/utils'

const router = useRouter()
const form = ref({ title: '', category: '其他', amount: '', invoiceNo: '', reason: '', image: null })
const error = ref('')
const loading = ref(false)
const previewUrl = ref('')

function onFile(e) {
  const f = e.target.files?.[0]
  if (!f) return
  if (!f.type.startsWith('image/')) {
    error.value = '请上传图片文件'
    return
  }
  form.value.image = f
  previewUrl.value = URL.createObjectURL(f)
  error.value = ''
}

// 压缩图片到 ~200KB，控制 Supabase 1GB 免费存储用量
async function compressImage(file) {
  return new Promise((resolve, reject) => {
    const img = new Image()
    const url = URL.createObjectURL(file)
    img.onload = () => {
      const max = 1200
      let { width, height } = img
      if (width > max || height > max) {
        const ratio = Math.min(max / width, max / height)
        width = Math.round(width * ratio)
        height = Math.round(height * ratio)
      }
      const canvas = document.createElement('canvas')
      canvas.width = width
      canvas.height = height
      const ctx = canvas.getContext('2d')
      ctx.drawImage(img, 0, 0, width, height)
      canvas.toBlob(
        (blob) => {
          URL.revokeObjectURL(url)
          blob ? resolve(blob) : reject(new Error('图片压缩失败'))
        },
        'image/jpeg',
        0.8
      )
    }
    img.onerror = reject
    img.src = url
  })
}

async function submit() {
  error.value = ''
  if (profileStatus.value !== 'active') {
    error.value = '账号未通过审核，无法提交'
    return
  }
  const f = form.value
  if (!f.title.trim() || !f.amount) {
    error.value = '请填写事由和金额'
    return
  }
  if (Number(f.amount) <= 0) {
    error.value = '金额必须大于 0'
    return
  }

  loading.value = true
  try {
    let receiptPath = ''
    if (f.image) {
      const compressed = await compressImage(f.image)
      const fileExt = 'jpg'
      const fileName = `${authState.user.id}/${crypto.randomUUID()}.${fileExt}`
      const { error: upErr } = await supabase.storage.from('receipts').upload(fileName, compressed, {
        contentType: 'image/jpeg',
        upsert: false,
      })
      if (upErr) throw new Error('发票上传失败：' + upErr.message)
      receiptPath = fileName
    }

    const { data, error: dbErr } = await supabase
      .from('claims')
      .insert({
        submitter_id: authState.user.id,
        title: f.title.trim(),
        category: f.category,
        amount: Number(f.amount),
        invoice_no: f.invoiceNo.trim(),
        reason: f.reason.trim(),
        receipt_path: receiptPath,
      })
      .select()
      .single()
    if (dbErr) throw new Error(dbErr.message)

    router.push(`/claims/${data.id}`)
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div>
    <div class="page-head">
      <div>
        <div class="page-title">提交报销</div>
        <div class="page-sub">填写报销信息，可附发票图片。提交后由财政/管理员审批</div>
      </div>
    </div>

    <div class="card" style="max-width: 560px">
      <div v-if="profileStatus !== 'active'" class="alert error">
        你的账号{{ profileStatus === 'pending' ? '待审核' : '已被禁用' }}，无法提交报销。请联系管理员。
      </div>

      <div class="field">
        <label>报销事由 *</label>
        <input v-model="form.title" placeholder="如：迎新晚会物资采购" :disabled="profileStatus !== 'active'" />
      </div>
      <div class="form-row">
        <div class="field">
          <label>科目分类</label>
          <select v-model="form.category" :disabled="profileStatus !== 'active'">
            <option v-for="c in CATEGORIES" :key="c" :value="c">{{ c }}</option>
          </select>
        </div>
        <div class="field">
          <label>金额（元）*</label>
          <input v-model="form.amount" type="number" step="0.01" min="0" placeholder="0.00" :disabled="profileStatus !== 'active'" />
        </div>
      </div>
      <div class="field">
        <label>发票号（选填）</label>
        <input v-model="form.invoiceNo" placeholder="如：发票编号" :disabled="profileStatus !== 'active'" />
      </div>
      <div class="field">
        <label>补充说明（选填）</label>
        <textarea v-model="form.reason" placeholder="用途、活动背景等" :disabled="profileStatus !== 'active'"></textarea>
      </div>
      <div class="field">
        <label>发票图片（选填，建议上传）</label>
        <div class="grow">
          <input type="file" accept="image/*" @change="onFile" :disabled="profileStatus !== 'active'" style="width:100%" />
          <div v-if="previewUrl" class="mt8"><img :src="previewUrl" class="receipt-img" alt="预览" /></div>
        </div>
      </div>

      <div v-if="error" class="alert error">{{ error }}</div>
      <button class="btn primary block" :disabled="loading || profileStatus !== 'active'" @click="submit">
        <span v-if="loading" class="spinner"></span>
        {{ loading ? '提交中…' : '提交报销单' }}
      </button>
    </div>
  </div>
</template>