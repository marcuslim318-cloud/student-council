<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { money, fmtDate, roleName, memberStatusName, statusName } from '../lib/utils'

const tab = ref('members')
const profiles = ref([])
const claims = ref([])
const logs = ref([])
const loading = ref(true)

const pendingMembers = computed(() => profiles.value.filter((p) => p.status === 'pending'))
const activeMembers = computed(() => profiles.value.filter((p) => p.status === 'active'))
const bannedMembers = computed(() => profiles.value.filter((p) => p.status === 'banned'))

async function load() {
  loading.value = true
  const [pRes, cRes, lRes] = await Promise.all([
    supabase.from('profiles').select('*').order('created_at', { ascending: true }),
    supabase.from('claims').select('*'),
    supabase.from('audit_logs').select('*').order('created_at', { ascending: false }).limit(200),
  ])
  profiles.value = pRes.data || []
  claims.value = cRes.data || []
  logs.value = lRes.data || []
  loading.value = false
}

async function updateMember(p, patch) {
  const { error } = await supabase.from('profiles').update(patch).eq('id', p.id)
  if (error) alert('操作失败：' + error.message)
  await load()
}

async function setRole(p, role) {
  if (!confirm(`将 ${p.name}（${p.student_id}）设置为「${roleName(role)}」？`)) return
  await updateMember(p, { role })
}

const profileName = (id) => profiles.value.find((p) => p.id === id)?.name || '未知'

async function deleteClaim(id) {
  if (!confirm('确定删除此报销单？会留下审计日志。')) return
  const { error } = await supabase.from('claims').delete().eq('id', id)
  if (error) alert('删除失败：' + error.message)
  await load()
}

function formatDetail(d) {
  try {
    return JSON.stringify(d)
  } catch {
    return String(d)
  }
}

function actionLabel(action) {
  return {
    status_change: '状态变更',
    delete: '删除',
    member_change: '成员变更',
  }[action] || action
}

// 导出审计日志为 Excel
const exportLogs = async () => {
  if (!logs.value.length) {
    alert('当前没有可导出的审计日志')
    return
  }
  try {
    const ExcelJS = (await import('exceljs')).default
    const wb = new ExcelJS.Workbook()
    const ws = wb.addWorksheet('审计日志')

    ws.columns = [
      { header: '时间', key: 'time', width: 20 },
      { header: '操作人', key: 'actor', width: 16 },
      { header: '动作', key: 'action', width: 14 },
      { header: '对象', key: 'target', width: 14 },
      { header: '明细', key: 'detail', width: 60 },
    ]
    ws.getRow(1).font = { bold: true, color: { argb: 'FFFFFFFF' } }
    ws.getRow(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF2F6FED' } }
    ws.getRow(1).height = 22

    for (const l of logs.value) {
      ws.addRow({
        time: fmtDate(l.created_at),
        actor: profileName(l.actor_id),
        action: actionLabel(l.action),
        target: l.target_type,
        detail: formatDetail(l.detail),
      })
    }
    ws.views = [{ state: 'frozen', ySplit: 1 }]

    const out = await wb.xlsx.writeBuffer()
    const blob = new Blob([out], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `审计日志_${new Date().toISOString().slice(0, 10)}.xlsx`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
  } catch (e) {
    alert('导出失败：' + (e?.message || e))
  }
}

onMounted(load)
</script>

<template>
  <div>
    <div class="page-head">
      <div>
        <div class="page-title">管理员后台</div>
        <div class="page-sub">成员审核 · 角色管理 · 审计日志 · 全部报销单</div>
      </div>
    </div>

    <div class="tabs">
      <button :class="{ active: tab === 'members' }" @click="tab = 'members'">成员管理</button>
      <button :class="{ active: tab === 'allclaims' }" @click="tab = 'allclaims'">全部报销单</button>
      <button :class="{ active: tab === 'logs' }" @click="tab = 'logs'">审计日志</button>
    </div>

    <div v-if="loading" class="loading">加载中…</div>

    <!-- 成员管理 -->
    <div v-else-if="tab === 'members'">
      <div class="card mb16">
        <div class="card-title">待审核注册（{{ pendingMembers.length }}）</div>
        <div v-if="!pendingMembers.length" class="empty" style="padding:16px">暂无待审核成员</div>
        <div v-else class="table-wrap">
          <table class="data">
            <tr><th>学号</th><th>姓名</th><th>职位</th><th>邮箱</th><th>注册时间</th><th>操作</th></tr>
            <tr v-for="p in pendingMembers" :key="p.id">
              <td>{{ p.student_id }}</td><td>{{ p.name }}</td><td>{{ p.position }}</td><td>{{ p.email }}</td><td>{{ fmtDate(p.created_at) }}</td>
              <td>
                <button class="btn sm success" @click="updateMember(p, { status: 'active' })">通过</button>
                <button class="btn sm danger" @click="updateMember(p, { status: 'banned' })">拒绝</button>
              </td>
            </tr>
          </table>
        </div>
      </div>

      <div class="card">
        <div class="card-title">全部成员</div>
        <div class="table-wrap">
          <table class="data">
            <tr><th>学号</th><th>姓名</th><th>职位</th><th>角色</th><th>状态</th><th>操作</th></tr>
            <tr v-for="p in [...activeMembers, ...bannedMembers]" :key="p.id">
              <td>{{ p.student_id }}</td>
              <td>{{ p.name }}</td>
              <td>{{ p.position }}</td>
              <td><span class="role-chip" :class="p.role">{{ roleName(p.role) }}</span></td>
              <td><span class="status-chip" :class="p.status">{{ memberStatusName(p.status) }}</span></td>
              <td style="white-space:nowrap">
                <button v-if="p.role !== 'admin'" class="btn sm" @click="setRole(p, 'finance')">设为财政</button>
                <button v-if="p.role === 'finance'" class="btn sm" @click="setRole(p, 'member')">取消财政</button>
                <button v-if="p.status === 'active'" class="btn sm danger" @click="updateMember(p, { status: 'banned' })">禁用</button>
                <button v-else class="btn sm success" @click="updateMember(p, { status: 'active' })">启用</button>
              </td>
            </tr>
          </table>
        </div>
      </div>
    </div>

    <!-- 全部报销单 -->
    <div v-else-if="tab === 'allclaims'">
      <div class="card">
        <div class="table-wrap">
          <table class="data">
            <tr><th>#</th><th>提交人</th><th>事由</th><th>科目</th><th>金额</th><th>状态</th><th>操作</th></tr>
            <tr v-for="c in claims" :key="c.id">
              <td>{{ c.id.slice(0, 6) }}</td>
              <td>{{ profileName(c.submitter_id) }}</td>
              <td>{{ c.title }}</td>
              <td>{{ c.category }}</td>
              <td>{{ money(c.amount) }}</td>
              <td><span class="badge" :class="c.status">{{ statusName(c.status) }}</span></td>
              <td style="white-space:nowrap">
                <RouterLink class="btn sm" :to="`/claims/${c.id}`">详情</RouterLink>
                <button class="btn sm danger" @click="deleteClaim(c.id)">删除</button>
              </td>
            </tr>
            <tr v-if="!claims.length"><td colspan="7" class="muted">暂无报销单</td></tr>
          </table>
        </div>
      </div>
    </div>

    <!-- 审计日志 -->
    <div v-else>
      <div class="card">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px">
          <div class="card-title" style="margin-bottom:0">审计日志（{{ logs.length }} 条）</div>
          <button class="btn sm" @click="exportLogs">⬇ 导出 Excel</button>
        </div>
        <div class="table-wrap">
          <table class="data">
            <tr><th>时间</th><th>操作人</th><th>动作</th><th>对象</th><th>明细</th></tr>
            <tr v-for="l in logs" :key="l.id">
              <td style="white-space:nowrap">{{ fmtDate(l.created_at) }}</td>
              <td>{{ profileName(l.actor_id) }}</td>
              <td>
                <span class="badge" :class="{
                  'submitted': l.action === 'delete',
                  'approved': l.action === 'status_change',
                  'paid': l.action === 'member_change'
                }">{{ l.action }}</span>
              </td>
              <td>{{ l.target_type }}</td>
              <td class="small muted" style="word-break:break-all;max-width:320px">{{ formatDetail(l.detail) }}</td>
            </tr>
            <tr v-if="!logs.length"><td colspan="5" class="muted">暂无日志</td></tr>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>