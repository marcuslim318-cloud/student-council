<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { gsap } from 'gsap'
import { loginWithStudentId } from '../lib/auth'

const router = useRouter()
const route = useRoute()

const studentId = ref('')
const password = ref('')
const error = ref('')
const loading = ref(false)

async function submit() {
  error.value = ''
  if (!studentId.value.trim() || !password.value) {
    error.value = '请输入学号和密码'
    return
  }
  loading.value = true
  try {
    await loginWithStudentId(studentId.value.trim(), password.value)
    const redirect = route.query.redirect || '/home'
    router.push(redirect)
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}

/* ---------- 3D 卡片（鼠标跟随） ---------- */
const cardRef = ref(null)
function onCardMove(e) {
  if (!cardRef.value || window.innerWidth < 900) return
  const r = cardRef.value.getBoundingClientRect()
  const px = (e.clientX - r.left) / r.width - 0.5
  const py = (e.clientY - r.top) / r.height - 0.5
  gsap.to(cardRef.value, {
    rotateY: px * 10,
    rotateX: -py * 8,
    transformPerspective: 1100,
    duration: 0.5,
    ease: 'power2.out',
  })
}
function onCardLeave() {
  if (!cardRef.value) return
  gsap.to(cardRef.value, {
    rotateY: 0,
    rotateX: 0,
    transformPerspective: 1100,
    duration: 0.8,
    ease: 'power3.out',
  })
}

/* ---------- GSAP 入场动画 ---------- */
let ctx = null
let mm = null
const videoRef = ref(null)

onMounted(() => {
  ctx = gsap.context(() => {
    gsap.timeline({ defaults: { ease: 'power3.out' } })
      .fromTo('.login-brand', { y: -24, opacity: 0 }, { y: 0, opacity: 1, duration: 0.6 })
      .fromTo('.login-hero-title', { y: 30, opacity: 0 }, { y: 0, opacity: 1, duration: 0.7 }, '-=0.3')
      .fromTo('.login-hero-sub', { y: 20, opacity: 0 }, { y: 0, opacity: 1, duration: 0.6 }, '-=0.35')
      .fromTo('.login-hero-points', { opacity: 0 }, { opacity: 1, duration: 0.6 }, '-=0.3')
      .fromTo(
        '.login-card-wrap',
        { y: 50, opacity: 0, rotateY: -14 },
        { y: 0, opacity: 1, rotateY: 0, duration: 0.9, transformPerspective: 1100, ease: 'power3.out' },
        '-=0.7',
      )

    /* 背景光斑缓慢浮动 */
    gsap.to('.login-blob-1', { y: -36, x: 28, duration: 7, yoyo: true, repeat: -1, ease: 'sine.inOut' })
    gsap.to('.login-blob-2', { y: 36, x: -28, duration: 8, yoyo: true, repeat: -1, ease: 'sine.inOut' })

    /* 悬浮角标 */
    gsap.to('.login-chip-1', { y: -12, duration: 3, yoyo: true, repeat: -1, ease: 'sine.inOut' })
    gsap.to('.login-chip-2', { y: 12, duration: 3.6, yoyo: true, repeat: -1, ease: 'sine.inOut' })
  })
  mm = gsap.matchMedia()
  mm.add('(max-width: 899px)', () => {
    gsap.set('.login-card-wrap', { transformPerspective: 900 })
  })
  if (videoRef.value) {
    videoRef.value.play().catch(() => {})
  }
})
onBeforeUnmount(() => {
  ctx && ctx.revert()
  mm && mm.revert()
})
</script>

<template>
  <div class="login">
    <!-- 背景视频 + 光斑 -->
    <div class="login-video-layer">
      <video ref="videoRef" autoplay muted loop playsinline preload="metadata" poster="https://assets.mixkit.co/videos/10417/10417-thumb-720-0.jpg">
        <source src="https://assets.mixkit.co/videos/10417/10417-720.mp4" type="video/mp4" />
      </video>
    </div>
    <div class="login-blob login-blob-1"></div>
    <div class="login-blob login-blob-2"></div>
    <div class="login-chip login-chip-1">🔒 RLS 行级权限</div>
    <div class="login-chip login-chip-2">📋 全流程审计</div>

    <div class="login-shell">
      <!-- 左侧：品牌介绍（CSS 网格左列） -->
      <div class="login-brand-panel">
        <div class="login-brand">学生会<span class="accent">报销</span></div>
        <h1 class="login-hero-title">报销，<span class="grad-text">一次提交</span><br />全程留痕，账目透明</h1>
        <p class="login-hero-sub">执委提交、财政审批、管理员打款，三步闭环。发票私有存储、行级权限、每一步自动审计。</p>
        <div class="login-hero-points">
          <div class="point">
            <span class="pt-icon">🛡️</span>
            <div><strong>服务端权限边界</strong><p>所有读写由 Postgres RLS 强制，前端只是 UX 呈现。</p></div>
          </div>
          <div class="point">
            <span class="pt-icon">⏱️</span>
            <div><strong>登录限速保护</strong><p>连续失败 5 次锁定 15 分钟，暴力破解被主动拦截。</p></div>
          </div>
          <div class="point">
            <span class="pt-icon">📒</span>
            <div><strong>公开账本</strong><p>全员可查每笔收支科目、金额与状态，财务透明零黑箱。</p></div>
          </div>
        </div>
        <RouterLink class="btn ghost login-back" to="/">← 返回首页</RouterLink>
      </div>

      <!-- 右侧：登录卡片（3D 玻璃） -->
      <div class="login-card-wrap" ref="cardRef" @mousemove="onCardMove" @mouseleave="onCardLeave">
        <div class="login-card">
          <div class="login-card-head">
            <div class="login-card-title">登录</div>
            <div class="login-card-en">Sign in to continue</div>
          </div>
          <div class="field">
            <label>学号</label>
            <input v-model="studentId" placeholder="请输入学号" @keyup.enter="submit" />
          </div>
          <div class="field">
            <label>密码</label>
            <input v-model="password" type="password" placeholder="请输入密码" @keyup.enter="submit" />
          </div>
          <div v-if="error" class="alert error">{{ error }}</div>
          <button class="btn cta block" :disabled="loading" @click="submit">
            <span v-if="loading" class="spinner"></span>
            {{ loading ? '登录中…' : '登 录' }}
          </button>
          <div class="login-links">
            <RouterLink to="/forgot-password">忘记密码？</RouterLink>
            <span>｜</span>
            <span>还没有账号？<RouterLink to="/register">注册</RouterLink></span>
          </div>
        </div>
        <div class="login-foot">登录失败 5 次将锁定 15 分钟 · 发票图片仅本人、财政、管理员可见</div>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* ============================================================
   Login · Zenvix 风格登录页
   复用全局设计 token + 背景视频 + 3D 卡片 + GSAP + CSS 网格
   ============================================================ */
.login {
  position: relative;
  min-height: 100svh;
  display: flex; align-items: center; justify-content: center;
  padding: 40px 24px;
  overflow: hidden;
  perspective: 1100px;
  background: #fff;
  font-family: var(--font-body);
  color: var(--text);
}

/* ---------- 背景视频 ---------- */
.login-video-layer { position: absolute; inset: -10%; z-index: 0; }
.login-video-layer video { width: 100%; height: 100%; object-fit: cover; opacity: .22; }
.login::before {
  content: '';
  position: absolute; inset: 0; z-index: 1;
  background:
    radial-gradient(110% 90% at 20% 10%, rgba(255, 255, 255, .94) 0%, rgba(255, 255, 255, .72) 55%, rgba(246, 249, 253, .92) 100%);
}
.login-blob {
  position: absolute; z-index: 1; border-radius: 50%;
  filter: blur(70px); opacity: .5; pointer-events: none;
}
.login-blob-1 { width: 460px; height: 460px; top: -120px; left: -140px; background: rgba(59, 130, 246, .26); }
.login-blob-2 { width: 500px; height: 500px; bottom: -160px; right: -160px; background: rgba(64, 106, 228, .2); }

/* ---------- 悬浮角标 ---------- */
.login-chip {
  position: absolute; z-index: 3;
  background: #fff; border: 1px solid var(--border); border-radius: var(--radius-pill);
  box-shadow: var(--shadow-lg); padding: 9px 16px; font-size: 12px; font-weight: 600;
}
.login-chip-1 { top: 24%; right: max(8%, calc((100% - 1180px) / 2)); }
.login-chip-2 { top: 64%; left: max(8%, calc((100% - 1180px) / 2)); }

/* ---------- 网格布局：左品牌 + 右表单 ---------- */
.login-shell {
  position: relative; z-index: 2;
  display: grid;
  grid-template-columns: minmax(0, 1.1fr) minmax(340px, 0.9fr);
  gap: 72px; align-items: center;
  max-width: 1100px; width: 100%; margin: 0 auto;
}

/* ---------- 左侧品牌 ---------- */
.login-brand {
  font-family: var(--font-heading); font-weight: 700; font-size: 20px;
  letter-spacing: -.4px; margin-bottom: 26px;
}
.login-brand .accent { color: var(--primary); }
.login-hero-title {
  font-family: var(--font-heading);
  font-size: clamp(38px, 4.6vw, 58px);
  font-weight: 700; letter-spacing: -2px; line-height: 1.06;
  margin-bottom: 22px;
}
.grad-text {
  background: var(--primary-grad);
  -webkit-background-clip: text; background-clip: text;
  -webkit-text-fill-color: transparent; color: transparent;
}
.login-hero-sub { color: var(--text-2); font-size: 15px; line-height: 1.75; max-width: 460px; margin-bottom: 34px; }
.login-hero-points { display: flex; flex-direction: column; gap: 20px; margin-bottom: 36px; }
.point { display: flex; gap: 14px; align-items: flex-start; }
.pt-icon { font-size: 20px; }
.point strong { font-size: 15px; font-weight: 700; }
.point p { color: var(--text-2); font-size: 13px; margin-top: 4px; line-height: 1.6; }
.login-back { background: transparent; }

/* ---------- 右侧登录卡片（3D 玻璃） ---------- */
.login-card-wrap {
  position: relative;
  transform-style: preserve-3d;
}
.login-card {
  background: rgba(255, 255, 255, .92);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-lg);
  padding: 34px 30px 26px;
  backdrop-filter: blur(14px);
}
.login-card-head { margin-bottom: 26px; }
.login-card-title { font-family: var(--font-heading); font-size: 26px; font-weight: 700; letter-spacing: -.8px; }
.login-card-en { color: var(--text-2); font-size: 12px; margin-top: 4px; letter-spacing: .3px; }
.login-links { display: flex; justify-content: center; align-items: center; gap: 8px; flex-wrap: wrap; margin-top: 20px; font-size: 13px; color: var(--text-2); }
.login-links a { color: var(--primary); text-decoration: none; font-weight: 600; }
.login-links a:hover { text-decoration: underline; }
.login-foot {
  margin-top: 18px; text-align: center;
  font-size: 12px; color: var(--text-3); line-height: 1.7;
}

/* ---------- 复用全局表单/按钮/提示 ---------- */
.btn { font-family: var(--font-body); }
.btn.ghost { background: transparent; border-color: var(--border); color: var(--text); }
.btn.ghost:hover { background: var(--card-soft); border-color: var(--text); color: var(--text); }

/* ============================================================
   响应式（Zenvix 断点）
   ============================================================ */
@media (max-width: 1024px) {
  .login-shell { gap: 44px; }
}

@media (max-width: 899px) {
  .login { padding: 40px 18px; }
  .login-shell { grid-template-columns: 1fr; gap: 36px; max-width: 460px; }
  .login-brand-panel { text-align: center; }
  .login-hero-sub { margin-left: auto; margin-right: auto; }
  .login-hero-points { align-items: center; }
  .point { max-width: 400px; text-align: left; }
  .login-chip { display: none; }
  .login-back { margin: 0 auto; }
}

@media (max-width: 479px) {
  .login-card { padding: 26px 20px 20px; }
  .login-hero-title { font-size: 34px; }
}
</style>
