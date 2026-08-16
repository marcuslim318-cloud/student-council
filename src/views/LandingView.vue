<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { gsap } from 'gsap'
import { ScrollTrigger } from 'gsap/ScrollTrigger'

gsap.registerPlugin(ScrollTrigger)

const heroRef = ref(null)
const dashRef = ref(null)
const videoRef = ref(null)

/* ---------- 3D 悬浮仪表盘（鼠标跟随） ---------- */
function onHeroMove(e) {
  if (!dashRef.value || window.innerWidth < 900) return
  const r = dashRef.value.getBoundingClientRect()
  const px = (e.clientX - r.left) / r.width - 0.5
  const py = (e.clientY - r.top) / r.height - 0.5
  gsap.to(dashRef.value, {
    rotateY: px * 14,
    rotateX: -py * 10,
    transformPerspective: 1200,
    duration: 0.5,
    ease: 'power2.out',
  })
}
function onHeroLeave() {
  if (!dashRef.value) return
  gsap.to(dashRef.value, {
    rotateY: 0,
    rotateX: 0,
    transformPerspective: 1200,
    duration: 0.8,
    ease: 'power3.out',
  })
}

/* ---------- GSAP 动画编排 ---------- */
let ctx = null
function setupAnimations() {
  ctx = gsap.context(() => {
    /* Hero 入场 */
    gsap.timeline({ defaults: { ease: 'power3.out' } })
      .fromTo('.nav-bar', { y: -24, opacity: 0 }, { y: 0, opacity: 1, duration: 0.7 })
      .fromTo('.hero-badge', { y: 18, opacity: 0 }, { y: 0, opacity: 1, duration: 0.5 }, '-=0.3')
      .fromTo('.hero-title', { y: 40, opacity: 0 }, { y: 0, opacity: 1, duration: 0.8 }, '-=0.2')
      .fromTo('.hero-sub', { y: 24, opacity: 0 }, { y: 0, opacity: 1, duration: 0.6 }, '-=0.4')
      .fromTo('.hero-cta', { y: 16, opacity: 0 }, { y: 0, opacity: 1, duration: 0.5 }, '-=0.3')
      .fromTo('.hero-trust', { opacity: 0 }, { opacity: 1, duration: 0.5 }, '-=0.2')
      .fromTo(
        '.hero-dash',
        { y: 90, opacity: 0, rotateX: 18 },
        { y: 0, opacity: 1, rotateX: 0, duration: 1, ease: 'power3.out', transformPerspective: 1200 },
        '-=0.7',
      )

    /* Hero 背景光斑缓慢浮动（视频之外的动态层次） */
    gsap.to('.hero-blob-1', { y: -40, x: 30, duration: 7, yoyo: true, repeat: -1, ease: 'sine.inOut' })
    gsap.to('.hero-blob-2', { y: 40, x: -30, duration: 8, yoyo: true, repeat: -1, ease: 'sine.inOut' })

    /* 悬浮角标（3D 层次感） */
    gsap.to('.float-chip-1', { y: -14, duration: 3, yoyo: true, repeat: -1, ease: 'sine.inOut' })
    gsap.to('.float-chip-2', { y: 12, duration: 3.6, yoyo: true, repeat: -1, ease: 'sine.inOut' })

    /* 品牌墙横向滚动 */
    gsap.to('.brand-track', { x: '-50%', duration: 22, repeat: -1, ease: 'none' })

    /* 通用滚动浮现 */
    gsap.utils.toArray('.reveal').forEach((el) => {
      gsap.fromTo(
        el,
        { y: 40, opacity: 0 },
        {
          y: 0,
          opacity: 1,
          duration: 0.8,
          ease: 'power2.out',
          scrollTrigger: { trigger: el, start: 'top 88%', toggleActions: 'play none none none' },
        },
      )
    })

    /* 特性卡片交错入场 */
    gsap.utils.toArray('.feature-card').forEach((el, i) => {
      gsap.fromTo(
        el,
        { y: 44, opacity: 0 },
        {
          y: 0,
          opacity: 1,
          duration: 0.7,
          delay: (i % 3) * 0.12,
          ease: 'power2.out',
          scrollTrigger: { trigger: el, start: 'top 90%', toggleActions: 'play none none none' },
        },
      )
    })

    /* 步骤卡片交错 */
    gsap.utils.toArray('.step-card').forEach((el, i) => {
      gsap.fromTo(
        el,
        { y: 36, opacity: 0 },
        {
          y: 0,
          opacity: 1,
          duration: 0.7,
          delay: i * 0.15,
          ease: 'power2.out',
          scrollTrigger: { trigger: el, start: 'top 90%', toggleActions: 'play none none none' },
        },
      )
    })

    /* 角色卡片 3D 翻转入场 */
    gsap.utils.toArray('.role-card').forEach((el, i) => {
      gsap.fromTo(
        el,
        { rotateY: 24, opacity: 0, x: i % 2 ? 40 : -40 },
        {
          rotateY: 0,
          opacity: 1,
          x: 0,
          transformPerspective: 900,
          duration: 0.8,
          ease: 'power2.out',
          scrollTrigger: { trigger: el, start: 'top 90%', toggleActions: 'play none none none' },
        },
      )
    })

    /* FAQ 展开项 */
    gsap.fromTo(
      '.faq-item',
      { y: 24, opacity: 0 },
      {
        y: 0,
        opacity: 1,
        stagger: 0.1,
        duration: 0.6,
        ease: 'power2.out',
        scrollTrigger: { trigger: '.faq-grid', start: 'top 90%', toggleActions: 'play none none none' },
      },
    )
  })
}

/* ---------- FAQ 手风琴 ---------- */
const faqs = [
  { q: '报销要经过哪些环节？', a: '执委提交报销单 → 财政审批 → 管理员打款。每一步都会自动写入审计日志，全程可追溯。' },
  { q: '发票图片安全吗？', a: '发票存于私有桶，行级权限（RLS）控制：仅本人、财政和管理员可见，其它成员无法访问。' },
  { q: '任何人都能看账本吗？', a: '系统内所有已登录成员都可查看公开账本（每笔报销的科目、金额与状态），保证财务透明。' },
  { q: '登录被锁定了怎么办？', a: '连续输错密码 5 次会锁定 15 分钟，之后自动解锁；忘记密码可走邮箱重置。' },
]
const openFaq = ref(0)

/* ---------- 生命周期 ---------- */
let mm = null
onMounted(() => {
  setupAnimations()
  /* 移动端禁用 3D 透视，保留轻量浮动 */
  mm = gsap.matchMedia()
  mm.add('(max-width: 899px)', () => {
    gsap.set('.hero-dash', { transformPerspective: 900 })
  })
  /* 背景视频自动播放（静音 + 循环 + 内联） */
  if (videoRef.value) {
    videoRef.value.play().catch(() => {})
  }
})
onBeforeUnmount(() => {
  ctx && ctx.revert()
  mm && mm.revert()
  ScrollTrigger.getAll().forEach((t) => t.kill())
})
</script>

<template>
  <div class="landing">
    <!-- ======== 顶部导航（Zenvix 悬浮胶囊） ======== -->
    <header class="nav-bar">
      <div class="nav-inner">
        <span class="nav-brand">学生会<span class="accent">报销</span></span>
        <nav class="nav-links">
          <a href="#features">功能</a>
          <a href="#overview">数据</a>
          <a href="#steps">流程</a>
          <a href="#security">安全</a>
          <a href="#roles">角色</a>
          <a href="#faq">常见问题</a>
        </nav>
        <div class="nav-actions">
          <RouterLink class="btn ghost" to="/login">登录</RouterLink>
          <RouterLink class="btn cta sm" to="/register">免费加入</RouterLink>
        </div>
      </div>
    </header>

    <!-- ======== Hero：背景视频 + 3D 仪表盘 ======== -->
    <section class="hero" ref="heroRef" @mousemove="onHeroMove" @mouseleave="onHeroLeave">
      <div class="hero-video-layer">
        <video ref="videoRef" autoplay muted loop playsinline preload="metadata" poster="https://assets.mixkit.co/videos/10417/10417-thumb-720-0.jpg">
          <source src="https://assets.mixkit.co/videos/10417/10417-720.mp4" type="video/mp4" />
        </video>
      </div>
      <div class="hero-blob hero-blob-1"></div>
      <div class="hero-blob hero-blob-2"></div>

      <div class="hero-content">
        <div class="hero-badge">✨ 学生会专属 · 报销 / 记账 / 公开账本</div>
        <h1 class="hero-title">
          报销，<span class="grad-text">一次提交</span><br />
          全程留痕，账目透明
        </h1>
        <p class="hero-sub">
          执委提交、财政审批、管理员打款，三步闭环。发票私有存储、行级权限、
          每一步自动审计，让每一笔学生会的钱都清清楚楚。
        </p>
        <div class="hero-cta">
          <RouterLink class="btn cta lg" to="/register">立即开始使用</RouterLink>
          <RouterLink class="btn ghost lg" to="/login">已有账号？登录</RouterLink>
        </div>
        <div class="hero-trust">
          <span class="trust-item">🛡️ 行级权限（RLS）</span>
          <span class="trust-item">📋 全流程审计日志</span>
          <span class="trust-item">⏱️ 5 次输错自动锁定</span>
        </div>
      </div>

      <!-- 3D 悬浮仪表盘（复刻系统账本风格） -->
      <div class="hero-dash" ref="dashRef">
        <div class="dash-head">
          <span class="dash-dot"></span><span class="dash-dot"></span><span class="dash-dot"></span>
          <span class="dash-title">公开账本</span>
          <span class="dash-live">● LIVE</span>
        </div>
        <div class="dash-summary">
          <div class="sum-item">
            <span class="sum-v">¥3,860.50</span>
            <span class="sum-l">本月已打款</span>
          </div>
          <div class="sum-item">
            <span class="sum-v">18</span>
            <span class="sum-l">报销单</span>
          </div>
          <div class="sum-item">
            <span class="sum-v">96%</span>
            <span class="sum-l">按时办结</span>
          </div>
        </div>
        <div class="dash-list">
          <div class="row" v-for="(r, i) in [
            { t: '海报打印费', c: '宣传部', a: '¥268.00', s: 'paid' },
            { t: '活动场地费', c: '外联部', a: '¥1,200.00', s: 'approved' },
            { t: '饮用水采购', c: '办公室', a: '¥86.50', s: 'paid' },
            { t: '志愿者胸牌', c: '组织部', a: '¥540.00', s: 'submitted' },
          ]" :key="i">
            <span class="row-title">{{ r.t }}</span>
            <span class="row-cat">{{ r.c }}</span>
            <span class="row-amount">{{ r.a }}</span>
            <span class="row-status" :class="r.s">{{ r.s === 'paid' ? '已打款' : r.s === 'approved' ? '已审批' : '待审批' }}</span>
          </div>
        </div>
        <div class="dash-foot">来自「公开账本」的实时示例</div>
      </div>

      <!-- 悬浮角标（3D 层次） -->
      <div class="float-chip float-chip-1">✅ 已打款</div>
      <div class="float-chip float-chip-2">🔒 RLS 加密</div>
    </section>

    <!-- ======== 品牌墙 ======== -->
    <section class="brand-section">
      <p class="brand-caption">一个系统，管好学生会的每一分钱</p>
      <div class="brand-marquee">
        <div class="brand-track">
          <span>执委提交</span><span>财政审批</span><span>管理员打款</span><span>公开账本</span>
          <span>审计留痕</span><span>发票私有</span><span>角色权限</span><span>登录限速</span>
          <span>执委提交</span><span>财政审批</span><span>管理员打款</span><span>公开账本</span>
          <span>审计留痕</span><span>发票私有</span><span>角色权限</span><span>登录限速</span>
        </div>
      </div>
    </section>

    <!-- ======== 核心功能（CSS 网格 + 特性卡） ======== -->
    <section class="features section" id="features">
      <div class="section-head reveal">
        <h2 class="section-title">核心功能</h2>
        <p class="section-sub">围绕报销闭环设计的每一环，都在为透明与效率服务。</p>
      </div>
      <div class="features-grid">
        <div class="feature-card f-1">
          <div class="feature-icon">📝</div>
          <h3>一键提交报销</h3>
          <p>执委在线填单：科目、金额、发票，一次提交，状态全程可见。</p>
        </div>
        <div class="feature-card f-2">
          <div class="feature-icon">🔄</div>
          <h3>审批状态机</h3>
          <p>待审批 → 已审批 → 已打款；驳回可改可重提，节点不可乱跳。</p>
        </div>
        <div class="feature-card f-3">
          <div class="feature-icon">📒</div>
          <h3>公开账本</h3>
          <p>全员可查每笔收支的科目、金额与状态，财务透明零黑箱。</p>
        </div>
        <div class="feature-card f-4">
          <div class="feature-icon">🔒</div>
          <h3>发票私有存储</h3>
          <p>发票存于私有桶，仅本人、财政、管理员可见，权限由 RLS 保障。</p>
        </div>
        <div class="feature-card f-5">
          <div class="feature-icon">🧾</div>
          <h3>全流程审计</h3>
          <p>提交、改单、审批、打款、删单自动落审计日志，谁改的一查便知。</p>
        </div>
        <div class="feature-card f-6">
          <div class="feature-icon">👥</div>
          <h3>三角色权限</h3>
          <p>执委 / 财政 / 管理员各司其职，审批链路上杜绝自我审批舞弊。</p>
        </div>
      </div>
    </section>

    <!-- ======== 数据面板展示（3D 透视 + 亮点） ======== -->
    <section class="overview section" id="overview">
      <div class="overview-grid">
        <div class="overview-copy reveal">
          <div class="section-head left">
            <h2 class="section-title">数据面板，一目了然</h2>
            <p class="section-sub">登录后即可访问个人报销记录、公开账本与审核工作台。</p>
          </div>
          <ul class="point-list">
            <li><span class="pt-icon">⚡</span><div><strong>我的报销记录</strong><p>随时查看自己每一单的当前状态与打款进度。</p></div></li>
            <li><span class="pt-icon">📊</span><div><strong>公开账本</strong><p>按科目、金额、状态浏览全部报销，财务透明。</p></div></li>
            <li><span class="pt-icon">🛡️</span><div><strong>审核工作台</strong><p>财政审批、管理员打款，一键完成并自动留痕。</p></div></li>
          </ul>
          <RouterLink class="btn cta" to="/login">登录查看 →</RouterLink>
        </div>
        <div class="overview-visual reveal">
          <div class="panel-card" v-for="(p, i) in [
            { k: '待审批', v: '4', c: 'submitted' },
            { k: '已审批', v: '7', c: 'approved' },
            { k: '已打款', v: '18', c: 'paid' },
            { k: '已驳回', v: '1', c: 'rejected' },
          ]" :key="i" :class="'panel-' + i">
            <span class="panel-k">{{ p.k }}</span>
            <span class="panel-v" :class="p.c">{{ p.v }}</span>
          </div>
        </div>
      </div>
    </section>

    <!-- ======== 使用流程（三步） ======== -->
    <section class="steps section" id="steps">
      <div class="section-head reveal">
        <h2 class="section-title">三步完成报销</h2>
        <p class="section-sub">从提交到到账，全程不超过几次点击。</p>
      </div>
      <div class="steps-grid">
        <div class="step-card">
          <span class="step-num">01</span>
          <h3>提交报销单</h3>
          <p>执委在线填写科目、金额，上传发票图片。</p>
        </div>
        <div class="step-arrow">→</div>
        <div class="step-card">
          <span class="step-num">02</span>
          <h3>财政审批</h3>
          <p>财政核对票据，通过或驳回；驳回可修改重提。</p>
        </div>
        <div class="step-arrow">→</div>
        <div class="step-card">
          <span class="step-num">03</span>
          <h3>管理员打款</h3>
          <p>管理员确认打款，状态归档，审计日志自动记录。</p>
        </div>
      </div>
    </section>

    <!-- ======== 安全 ======== -->
    <section class="security section" id="security">
      <div class="security-grid">
        <div class="security-card reveal">
          <span class="sec-icon">🔐</span>
          <h3>服务端权限边界</h3>
          <p>所有读写由 Postgres 行级权限（RLS）在服务端强制，前端只是 UX 呈现。</p>
        </div>
        <div class="security-card reveal">
          <span class="sec-icon">🚪</span>
          <h3>登录限速</h3>
          <p>连续失败 5 次锁定 15 分钟，暴力破解被系统主动拦截。</p>
        </div>
        <div class="security-card reveal">
          <span class="sec-icon">🗂️</span>
          <h3>发票私有桶</h3>
          <p>票据只存私有存储桶，接口级鉴权，成员之间互相不可见。</p>
        </div>
      </div>
    </section>

    <!-- ======== 角色 ======== -->
    <section class="roles section" id="roles">
      <div class="section-head reveal">
        <h2 class="section-title">为三角色各司其职</h2>
        <p class="section-sub">清晰分工，防止流程中的人为黑箱。</p>
      </div>
      <div class="roles-grid">
        <div class="role-card">
          <span class="role-tag member">执委</span>
          <h3>提交报销</h3>
          <p>提交自己的报销单、随时追踪进度、查看公开账本。</p>
        </div>
        <div class="role-card">
          <span class="role-tag finance">财政</span>
          <h3>审批流转</h3>
          <p>审批任意执委的报销、查看审计日志；不能审批自己的单。</p>
        </div>
        <div class="role-card">
          <span class="role-tag admin">管理员</span>
          <h3>打款与治理</h3>
          <p>打款归档、管理成员角色、删除违规单、审计全览。</p>
        </div>
      </div>
    </section>

    <!-- ======== FAQ ======== -->
    <section class="faq section" id="faq">
      <div class="section-head reveal">
        <h2 class="section-title">常见问题</h2>
        <p class="section-sub">还有疑问？加入后随时在系统内操作即可。</p>
      </div>
      <div class="faq-grid">
        <div v-for="(f, i) in faqs" :key="i" class="faq-item" :class="{ open: openFaq === i }">
          <button class="faq-q" @click="openFaq = openFaq === i ? -1 : i">
            <span>{{ f.q }}</span>
            <span class="faq-caret">{{ openFaq === i ? '−' : '+' }}</span>
          </button>
          <div v-show="openFaq === i" class="faq-a">{{ f.a }}</div>
        </div>
      </div>
    </section>

    <!-- ======== 最终 CTA → 登录页 ======== -->
    <section class="cta-final">
      <div class="cta-card reveal">
        <h2 class="cta-title">让报销，从今天开始变简单</h2>
        <p class="cta-sub">加入学生会报销记账系统，体验全流程透明、权限分明的财务管理。</p>
        <RouterLink class="btn cta lg" to="/login">进入登录页</RouterLink>
      </div>
    </section>

    <footer class="footer">
      <span>学生会报销记账系统 · 报销 / 记账 / 公开账本</span>
      <span>隐私与权限由 Supabase 行级安全策略保障</span>
    </footer>
  </div>
</template>

<style scoped>
/* ============================================================
   Landing · Zenvix 风格落地页
   复用全局设计 token（--primary-grad / --card-soft / --radius-pill 等）
   ============================================================ */
.landing {
  background: #fff;
  color: var(--text);
  font-family: var(--font-body);
  overflow-x: clip;
}

/* ---------- 导航 ---------- */
.nav-bar {
  position: fixed; top: 0; left: 0; right: 0; z-index: 100;
  padding: 18px 24px;
  pointer-events: none;
}
.nav-inner {
  pointer-events: auto;
  max-width: 1180px; margin: 0 auto;
  display: flex; align-items: center; gap: 18px;
  background: rgba(255, 255, 255, .86);
  border: 1px solid var(--border);
  border-radius: 16px;
  padding: 9px 12px 9px 22px;
  box-shadow: 0 0 0 4px rgba(221, 229, 237, .7), var(--shadow);
  backdrop-filter: blur(10px);
}
.nav-brand { font-family: var(--font-heading); font-weight: 700; font-size: 18px; letter-spacing: -.4px; white-space: nowrap; }
.nav-brand .accent { color: var(--primary); }
.nav-links { display: flex; gap: 2px; flex: 1; overflow-x: auto; }
.nav-links a {
  color: var(--text-2); text-decoration: none; padding: 8px 14px;
  border-radius: var(--radius-pill); font-weight: 500; font-size: 14px; white-space: nowrap;
  transition: all .2s ease;
}
.nav-links a:hover { background: var(--card-soft); color: var(--text); }
.nav-actions { display: flex; gap: 8px; align-items: center; white-space: nowrap; }
.btn { font-family: var(--font-body); }
.btn.ghost { background: transparent; border-color: var(--border); color: var(--text); }
.btn.ghost:hover { background: var(--card-soft); border-color: var(--text); color: var(--text); }
.btn.lg { padding: 13px 30px; font-size: 15px; }

/* ---------- Hero ---------- */
.hero {
  position: relative;
  min-height: 100svh;
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  padding: 130px 24px 90px;
  text-align: center;
  overflow: hidden;
  perspective: 1200px;
}
.hero-video-layer {
  position: absolute; inset: -10%;
  z-index: 0;
}
.hero-video-layer video {
  width: 100%; height: 100%; object-fit: cover;
  opacity: .28;
  filter: saturate(1.05);
}
.hero::before {
  content: '';
  position: absolute; inset: 0; z-index: 1;
  background:
    radial-gradient(120% 80% at 50% 0%, rgba(255, 255, 255, .92) 0%, rgba(255, 255, 255, .6) 55%, rgba(246, 249, 253, .9) 100%);
}
.hero-blob {
  position: absolute; z-index: 1; border-radius: 50%;
  filter: blur(70px); opacity: .5; pointer-events: none;
}
.hero-blob-1 { width: 480px; height: 480px; top: -120px; left: -140px; background: rgba(59, 130, 246, .28); }
.hero-blob-2 { width: 520px; height: 520px; bottom: -160px; right: -160px; background: rgba(64, 106, 228, .22); }

.hero-content { position: relative; z-index: 2; max-width: 820px; }
.hero-badge {
  display: inline-flex; align-items: center; gap: 6px;
  background: rgba(255, 255, 255, .7); border: 1px solid var(--border);
  padding: 7px 16px; border-radius: var(--radius-pill);
  font-size: 13px; font-weight: 600; color: var(--text-2);
  box-shadow: var(--shadow);
}
.hero-title {
  font-family: var(--font-heading);
  font-size: clamp(42px, 6.4vw, 76px);
  font-weight: 700; letter-spacing: -2.4px; line-height: 1.04;
  margin: 26px 0 22px;
}
.grad-text {
  background: var(--primary-grad);
  -webkit-background-clip: text; background-clip: text;
  -webkit-text-fill-color: transparent; color: transparent;
}
.hero-sub {
  font-size: clamp(15px, 1.6vw, 18px);
  color: var(--text-2); max-width: 620px; margin: 0 auto 30px; line-height: 1.7;
}
.hero-cta { display: flex; gap: 14px; justify-content: center; flex-wrap: wrap; }
.hero-trust {
  display: flex; gap: 22px; justify-content: center; flex-wrap: wrap;
  margin-top: 34px; font-size: 13px; color: var(--text-2); font-weight: 500;
}
.trust-item { display: inline-flex; align-items: center; gap: 6px; }

/* ---------- 3D 悬浮仪表盘 ---------- */
.hero-dash {
  position: relative; z-index: 2;
  width: min(680px, 92%);
  margin: 64px auto 0;
  background: rgba(255, 255, 255, .92);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-lg);
  padding: 18px 20px 14px;
  text-align: left;
  transform-style: preserve-3d;
}
.dash-head { display: flex; align-items: center; gap: 6px; margin-bottom: 14px; }
.dash-dot { width: 9px; height: 9px; border-radius: 50%; background: var(--card-soft); }
.dash-dot:nth-child(1) { background: #f28778; }
.dash-dot:nth-child(2) { background: var(--amber); }
.dash-dot:nth-child(3) { background: var(--green-2); }
.dash-title { font-family: var(--font-heading); font-weight: 700; font-size: 14px; margin-left: 6px; letter-spacing: -.2px; }
.dash-live { margin-left: auto; font-size: 11px; font-weight: 700; color: var(--green); letter-spacing: .5px; }
.dash-summary {
  display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; margin-bottom: 14px;
}
.sum-item {
  background: var(--card-soft); border: 1px solid var(--border); border-radius: var(--radius-sm);
  padding: 12px 14px;
}
.sum-v { display: block; font-family: var(--font-heading); font-weight: 700; font-size: 20px; letter-spacing: -.6px; }
.sum-l { font-size: 11px; color: var(--text-2); font-weight: 500; }
.dash-list { display: flex; flex-direction: column; gap: 8px; }
.row {
  display: flex; align-items: center; gap: 10px;
  background: #fff; border: 1px solid var(--border); border-radius: 12px;
  padding: 10px 14px; font-size: 13px;
}
.row-title { font-weight: 600; }
.row-cat { color: var(--text-2); font-size: 12px; background: var(--card-soft); padding: 2px 8px; border-radius: 999px; }
.row-amount { margin-left: auto; font-family: var(--font-heading); font-weight: 700; }
.row-status { font-size: 11px; font-weight: 700; padding: 3px 10px; border-radius: 999px; }
.row-status.paid { background: #d9f7e5; color: #067647; }
.row-status.approved { background: #e0f2fe; color: #0369a1; }
.row-status.submitted { background: #fff3d6; color: #b45309; }
.dash-foot { margin-top: 12px; text-align: center; font-size: 11px; color: var(--text-3); }

/* ---------- 悬浮角标 ---------- */
.float-chip {
  position: absolute; z-index: 3;
  background: #fff; border: 1px solid var(--border); border-radius: var(--radius-pill);
  box-shadow: var(--shadow-lg); padding: 10px 18px; font-size: 13px; font-weight: 600;
}
.float-chip-1 { top: 30%; right: max(6%, calc((100% - 1180px) / 2)); }
.float-chip-2 { top: 56%; left: max(6%, calc((100% - 1180px) / 2)); }

/* ---------- 品牌墙 ---------- */
.brand-section { padding: 34px 24px; border-top: 1px solid var(--border); }
.brand-caption { text-align: center; color: var(--text-3); font-size: 13px; font-weight: 500; margin-bottom: 20px; letter-spacing: .4px; }
.brand-marquee { overflow: hidden; -webkit-mask-image: linear-gradient(90deg, transparent, #000 12%, #000 88%, transparent); mask-image: linear-gradient(90deg, transparent, #000 12%, #000 88%, transparent); }
.brand-track { display: flex; gap: 14px; width: max-content; }
.brand-track span {
  background: var(--card-soft); border: 1px solid var(--border); border-radius: var(--radius-pill);
  padding: 8px 20px; font-size: 13px; font-weight: 600; color: var(--text-2); white-space: nowrap;
}

/* ---------- 通用 section ---------- */
.section { padding: 110px 24px; }
.section-head { text-align: center; max-width: 640px; margin: 0 auto 54px; }
.section-head.left { text-align: left; margin: 0 0 28px; }
.section-title { font-family: var(--font-heading); font-size: clamp(32px, 4vw, 46px); font-weight: 700; letter-spacing: -1.6px; line-height: 1.1; }
.section-sub { color: var(--text-2); margin-top: 14px; font-size: 15px; line-height: 1.7; }

/* ---------- 特性（CSS 网格 bento） ---------- */
.features-grid {
  display: grid; gap: 18px; max-width: 1100px; margin: 0 auto;
  grid-template-columns: repeat(3, 1fr);
}
.feature-card {
  background: var(--card-soft); border: 1px solid var(--border); border-radius: var(--radius-lg);
  padding: 30px 26px;
  transition: transform .3s ease, box-shadow .3s ease;
  will-change: transform;
}
.feature-card:hover { transform: translateY(-6px) rotateX(2deg); box-shadow: var(--shadow-lg); }
.f-1, .f-6 { background: linear-gradient(180deg, #eef3ff, #f7f9fe); }
.feature-icon { font-size: 26px; margin-bottom: 16px; }
.feature-card h3 { font-family: var(--font-heading); font-size: 19px; font-weight: 700; letter-spacing: -.4px; margin-bottom: 10px; }
.feature-card p { color: var(--text-2); font-size: 14px; line-height: 1.7; }

/* ---------- 数据面板 ---------- */
.overview { background: linear-gradient(180deg, #f7f9fd 0%, #ffffff 100%); }
.overview-grid {
  display: grid; grid-template-columns: 1fr 1fr; gap: 60px; align-items: center; max-width: 1100px; margin: 0 auto;
}
.point-list { list-style: none; margin: 0 0 30px; padding: 0; display: flex; flex-direction: column; gap: 22px; }
.point-list li { display: flex; gap: 14px; align-items: flex-start; }
.pt-icon { font-size: 20px; }
.point-list strong { font-size: 15px; font-weight: 700; }
.point-list p { color: var(--text-2); font-size: 13px; margin-top: 4px; line-height: 1.6; }
.overview-visual {
  display: grid; grid-template-columns: 1fr 1fr; gap: 18px;
  perspective: 900px;
}
.panel-card {
  background: #fff; border: 1px solid var(--border); border-radius: var(--radius);
  box-shadow: var(--shadow); padding: 26px 22px; text-align: center;
  transition: transform .3s ease, box-shadow .3s ease;
}
.panel-card:hover { transform: translateY(-6px) rotateY(3deg); box-shadow: var(--shadow-lg); }
.panel-1, .panel-3 { background: var(--card-soft); }
.panel-k { display: block; font-size: 13px; color: var(--text-2); font-weight: 500; margin-bottom: 10px; }
.panel-v { font-family: var(--font-heading); font-size: 40px; font-weight: 700; letter-spacing: -1.4px; }
.panel-v.submitted { color: #b45309; }
.panel-v.approved { color: #0369a1; }
.panel-v.paid { color: #067647; }
.panel-v.rejected { color: #b42318; }

/* ---------- 流程 ---------- */
.steps-grid {
  display: grid; grid-template-columns: 1fr auto 1fr auto 1fr; gap: 18px; align-items: stretch; max-width: 1000px; margin: 0 auto;
}
.step-card {
  background: #fff; border: 1px solid var(--border); border-radius: var(--radius-lg);
  padding: 30px 26px; box-shadow: var(--shadow); text-align: center;
  transition: transform .3s ease, box-shadow .3s ease;
}
.step-card:hover { transform: translateY(-6px); box-shadow: var(--shadow-lg); }
.step-num {
  display: inline-flex; align-items: center; justify-content: center;
  width: 46px; height: 46px; border-radius: 50%;
  background: var(--primary-grad); color: #fff; font-weight: 700; font-size: 15px;
  box-shadow: var(--shadow-glow); margin-bottom: 18px;
}
.step-card h3 { font-family: var(--font-heading); font-size: 19px; font-weight: 700; letter-spacing: -.4px; margin-bottom: 10px; }
.step-card p { color: var(--text-2); font-size: 14px; line-height: 1.7; }
.step-arrow { align-self: center; font-size: 26px; color: var(--primary-3); font-weight: 600; }

/* ---------- 安全 ---------- */
.security { background: linear-gradient(180deg, #ffffff, #f7f9fd); }
.security-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 18px; max-width: 1100px; margin: 0 auto; }
.security-card {
  background: #fff; border: 1px solid var(--border); border-radius: var(--radius-lg);
  padding: 30px 26px; box-shadow: var(--shadow);
  transition: transform .3s ease, box-shadow .3s ease;
}
.security-card:hover { transform: translateY(-6px) rotateX(2deg); box-shadow: var(--shadow-lg); }
.sec-icon { font-size: 26px; margin-bottom: 16px; display: inline-block; }
.security-card h3 { font-family: var(--font-heading); font-size: 18px; font-weight: 700; letter-spacing: -.3px; margin-bottom: 10px; }
.security-card p { color: var(--text-2); font-size: 14px; line-height: 1.7; }

/* ---------- 角色 ---------- */
.roles-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 18px; max-width: 1000px; margin: 0 auto; }
.role-card {
  background: #fff; border: 1px solid var(--border); border-radius: var(--radius-lg);
  padding: 32px 28px; box-shadow: var(--shadow); text-align: center;
  transition: transform .3s ease, box-shadow .3s ease;
  transform-style: preserve-3d;
}
.role-card:hover { transform: translateY(-6px) rotateY(3deg); box-shadow: var(--shadow-lg); }
.role-tag {
  display: inline-block; font-size: 12px; font-weight: 700; letter-spacing: .3px;
  padding: 4px 14px; border-radius: 999px; margin-bottom: 16px;
}
.role-tag.member { background: #e8edfe; color: var(--primary); }
.role-tag.finance { background: #d9f7e5; color: #067647; }
.role-tag.admin { background: #fff3d6; color: #b45309; }
.role-card h3 { font-family: var(--font-heading); font-size: 20px; font-weight: 700; letter-spacing: -.4px; margin-bottom: 10px; }
.role-card p { color: var(--text-2); font-size: 14px; line-height: 1.7; }

/* ---------- FAQ ---------- */
.faq-grid { max-width: 760px; margin: 0 auto; display: flex; flex-direction: column; gap: 12px; }
.faq-item {
  background: #fff; border: 1px solid var(--border); border-radius: var(--radius);
  overflow: hidden; transition: box-shadow .25s ease;
}
.faq-item.open { box-shadow: var(--shadow); }
.faq-q {
  width: 100%; display: flex; align-items: center; justify-content: space-between; gap: 12px;
  background: none; border: none; cursor: pointer; padding: 18px 20px;
  font-family: var(--font-body); font-size: 15px; font-weight: 600; color: var(--text);
}
.faq-caret { font-size: 20px; color: var(--primary); font-weight: 700; }
.faq-a { padding: 0 20px 18px; color: var(--text-2); font-size: 14px; line-height: 1.7; }

/* ---------- 最终 CTA ---------- */
.cta-final { padding: 40px 24px 110px; }
.cta-card {
  max-width: 1000px; margin: 0 auto; text-align: center;
  background: linear-gradient(180deg, #3b82f6, #406ae4);
  border-radius: var(--radius-lg);
  padding: 70px 40px;
  box-shadow: var(--shadow-glow);
}
.cta-title { font-family: var(--font-heading); color: #fff; font-size: clamp(30px, 4vw, 44px); font-weight: 700; letter-spacing: -1.4px; line-height: 1.12; }
.cta-sub { color: rgba(255, 255, 255, .9); margin: 16px auto 30px; max-width: 480px; font-size: 15px; line-height: 1.7; }
.cta-final .btn { background: #fff; border-color: #fff; color: var(--primary); box-shadow: none; }
.cta-final .btn:hover { background: var(--card-soft); border-color: #fff; color: var(--primary-dark); }

/* ---------- 页脚 ---------- */
.footer {
  border-top: 1px solid var(--border);
  padding: 26px 24px;
  display: flex; justify-content: space-between; align-items: center; gap: 12px; flex-wrap: wrap;
  font-size: 12px; color: var(--text-3);
}

/* ============================================================
   响应式（Zenvix 断点）
   ============================================================ */
@media (max-width: 1024px) {
  .features-grid { grid-template-columns: repeat(2, 1fr); }
  .overview-grid { grid-template-columns: 1fr; gap: 40px; }
  .security-grid { grid-template-columns: repeat(2, 1fr); }
  .roles-grid { grid-template-columns: repeat(2, 1fr); }
  .steps-grid { grid-template-columns: 1fr auto 1fr auto 1fr; }
}

@media (max-width: 899px) {
  .hero { padding-top: 120px; }
  .nav-links { display: none; }
  .hero-dash { margin-top: 44px; }
  .float-chip { display: none; }
  .steps-grid { grid-template-columns: 1fr; }
  .step-arrow { transform: rotate(90deg); text-align: center; padding: 6px 0; }
}

@media (max-width: 767px) {
  .nav-bar { padding: 12px 14px; }
  .nav-inner { padding: 8px 10px 8px 16px; }
  .features-grid { grid-template-columns: 1fr; }
  .security-grid { grid-template-columns: 1fr; }
  .roles-grid { grid-template-columns: 1fr; }
  .section { padding: 80px 18px; }
  .hero { padding: 110px 18px 70px; }
  .hero-cta .btn.lg { width: 100%; }
  .hero-dash { padding: 14px 12px 10px; }
  .dash-summary { grid-template-columns: 1fr; }
  .overview-visual { grid-template-columns: 1fr; }
  .cta-card { padding: 46px 22px; }
  .footer { justify-content: center; text-align: center; }
}
</style>
