export function money(v) {
  return '¥' + Number(v || 0).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

export function fmtDate(iso) {
  if (!iso) return '—'
  const d = new Date(iso)
  if (isNaN(d)) return '—'
  const p = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`
}

export function fmtDateShort(iso) {
  if (!iso) return '—'
  const d = new Date(iso)
  if (isNaN(d)) return '—'
  const p = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`
}

export const CATEGORIES = ['物料购置', '活动场地', '交通出行', '印刷宣传', '奖品礼品', '办公用品', '餐费', '其他']

export const STATUS_META = {
  submitted: { label: '待审核', cls: 'submitted', icon: '⏳' },
  approved: { label: '已通过', cls: 'approved', icon: '✓' },
  paid: { label: '已打款', cls: 'paid', icon: '💰' },
  rejected: { label: '已驳回', cls: 'rejected', icon: '✗' },
}

export function roleName(role) {
  return { admin: '管理员', finance: '财政', member: '执委' }[role] || role
}

export function statusName(status) {
  return STATUS_META[status]?.label || status
}

export function memberStatusName(status) {
  return { pending: '待审核', active: '已通过', banned: '已禁用' }[status] || status
}

export async function downloadText(filename, content, mime) {
  const blob = new Blob([content], { type: mime || 'text/plain;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}