import { defineConfig } from 'vitepress'
import { withMermaid } from 'vitepress-plugin-mermaid'
import mathjax3 from 'markdown-it-mathjax3'
import footnote from 'markdown-it-footnote'
import container from 'markdown-it-container'

const mathjaxTags = [
  'mjx-container',
  'mjx-assistive-mml',
  'math',
  'mrow',
  'mi',
  'mo',
  'mn',
  'msup',
  'msub',
  'msubsup',
  'mfrac',
  'msqrt',
  'mtext',
  'mtable',
  'mtr',
  'mtd',
  'semantics',
  'annotation',
]

function stripStyle(html: string): string {
  return html.replace(/<style[\s\S]*?<\/style>/g, '')
}

function registerContainer(md: any, name: string, defaultTitle: string) {
  md.use(container, name, {
    render(tokens: any[], idx: number) {
      const token = tokens[idx]
      const info = token.info.trim().slice(name.length).trim()
      const title = info || defaultTitle

      if (token.nesting === 1) {
        return `<div class="custom-block ${name}"><p class="custom-block-title">${md.utils.escapeHtml(title)}</p>\n`
      }

      return '</div>\n'
    },
  })
}

function normalizeBase(value: string | undefined): string {
  if (!value) return '/'

  const withLeadingSlash = value.startsWith('/') ? value : `/${value}`
  return withLeadingSlash.endsWith('/') ? withLeadingSlash : `${withLeadingSlash}/`
}

const siteBase = normalizeBase(process.env.VITEPRESS_BASE)

const zhNav = [
  { text: 'Booklet', link: '/booklet/' },
  { text: 'Docs', link: '/docs/' },
  { text: 'Roadmap', link: '/roadmap/' },
]

const enNav = [
  { text: 'Booklet', link: '/en/booklet/' },
  { text: 'Docs', link: '/en/docs/' },
  { text: 'Roadmap', link: '/en/roadmap/' },
]

const zhSidebar = {
  '/booklet/': [
    {
      text: 'Booklet',
      items: [
        { text: '序言', link: '/prologue' },
        { text: 'Booklet 首页', link: '/booklet/' },
      ],
    },
    {
      text: 'FV 实践直觉',
      items: [
        { text: '初识 Formal Verification', link: '/booklet/01-practice-intuition/01-introduction' },
        { text: '显式状态模型检查', link: '/booklet/01-practice-intuition/02-explicit-state-model-checking' },
        { text: '规格接口', link: '/booklet/01-practice-intuition/03-spec-interface' },
        { text: '规格与实现', link: '/booklet/01-practice-intuition/04-spec-and-implementation' },
      ],
    },
    {
      text: '模型表达',
      items: [
        { text: '路线', link: '/booklet/02-model-expression/' },
      ],
    },
    {
      text: '时序性质',
      items: [
        { text: '路线', link: '/booklet/03-temporal-properties/' },
      ],
    },
    {
      text: '定理证明',
      items: [
        { text: '路线', link: '/booklet/04-theorem-proving/' },
      ],
    },
    {
      text: '工程集成',
      items: [
        { text: '路线', link: '/booklet/05-engineering-integration/' },
      ],
    },
  ],
  '/docs/': [
    {
      text: 'Docs',
      items: [
        { text: 'Docs 首页', link: '/docs/' },
        { text: '库接口', link: '/docs/library' },
        { text: '开发命令', link: '/docs/development' },
      ],
    },
  ],
  '/roadmap/': [
    {
      text: '路线图',
      items: [
        { text: '概览', link: '/roadmap/' },
        { text: '当前状态', link: '/roadmap/status' },
        { text: '开发日志', link: '/roadmap/devlog' },
        { text: '完成信号', link: '/roadmap/completion-signals' },
      ],
    },
    {
      text: '技术轨道',
      items: [
        { text: '检查器核心', link: '/roadmap/tracks/checker-core' },
        { text: '规格表达层', link: '/roadmap/tracks/specification-surface' },
        { text: '状态空间工程', link: '/roadmap/tracks/state-space-engineering' },
        { text: '性质系统', link: '/roadmap/tracks/property-system' },
        { text: '符号方法', link: '/roadmap/tracks/symbolic-methods' },
        { text: '受限 Zig 验证', link: '/roadmap/tracks/restricted-zig-verification' },
        { text: '证明边界', link: '/roadmap/tracks/proof-boundary' },
        { text: '工具链集成', link: '/roadmap/tracks/toolchain-integration' },
      ],
    },
  ],
}

const enSidebar = {
  '/en/booklet/': [
    {
      text: 'Booklet',
      items: [
        { text: 'Prologue', link: '/en/prologue' },
        { text: 'Booklet Home', link: '/en/booklet/' },
      ],
    },
    {
      text: 'FV Practice Intuition',
      items: [
        { text: 'Introduction to Formal Verification', link: '/en/booklet/01-practice-intuition/01-introduction' },
        { text: 'Explicit-State Model Checking', link: '/en/booklet/01-practice-intuition/02-explicit-state-model-checking' },
        { text: 'Specification Interface', link: '/en/booklet/01-practice-intuition/03-spec-interface' },
        { text: 'Specification and Implementation', link: '/en/booklet/01-practice-intuition/04-spec-and-implementation' },
      ],
    },
    {
      text: 'Model Expression',
      items: [
        { text: 'Route', link: '/en/booklet/02-model-expression/' },
      ],
    },
    {
      text: 'Temporal Properties',
      items: [
        { text: 'Route', link: '/en/booklet/03-temporal-properties/' },
      ],
    },
    {
      text: 'Theorem Proving',
      items: [
        { text: 'Route', link: '/en/booklet/04-theorem-proving/' },
      ],
    },
    {
      text: 'Engineering Integration',
      items: [
        { text: 'Route', link: '/en/booklet/05-engineering-integration/' },
      ],
    },
  ],
  '/en/docs/': [
    {
      text: 'Docs',
      items: [
        { text: 'Docs Home', link: '/en/docs/' },
        { text: 'Library Interface', link: '/en/docs/library' },
        { text: 'Development Commands', link: '/en/docs/development' },
      ],
    },
  ],
  '/en/roadmap/': [
    {
      text: 'Roadmap',
      items: [
        { text: 'Overview', link: '/en/roadmap/' },
        { text: 'Status', link: '/en/roadmap/status' },
        { text: 'Devlog', link: '/en/roadmap/devlog' },
        { text: 'Completion Signals', link: '/en/roadmap/completion-signals' },
      ],
    },
    {
      text: 'Technical Tracks',
      items: [
        { text: 'Checker Core', link: '/en/roadmap/tracks/checker-core' },
        { text: 'Specification Surface', link: '/en/roadmap/tracks/specification-surface' },
        { text: 'State-Space Engineering', link: '/en/roadmap/tracks/state-space-engineering' },
        { text: 'Property System', link: '/en/roadmap/tracks/property-system' },
        { text: 'Symbolic Methods', link: '/en/roadmap/tracks/symbolic-methods' },
        { text: 'Restricted Zig Verification', link: '/en/roadmap/tracks/restricted-zig-verification' },
        { text: 'Proof Boundary', link: '/en/roadmap/tracks/proof-boundary' },
        { text: 'Toolchain Integration', link: '/en/roadmap/tracks/toolchain-integration' },
      ],
    },
  ],
}

export default withMermaid(
  defineConfig({
    title: 'Oxpecker',
    description: '让 AI 生成的代码更容易验证',
    lang: 'zh-CN',
    base: siteBase,
    cleanUrls: true,
    lastUpdated: true,
    themeConfig: {
      siteTitle: '~/oxpecker',
      nav: zhNav,
      sidebar: zhSidebar,
      search: {
        provider: 'local',
      },
      outline: {
        level: [2, 2],
        label: '本页内容',
      },
      docFooter: {
        prev: '上一篇',
        next: '下一篇',
      },
      lastUpdated: {
        text: '最后更新',
        formatOptions: {
          dateStyle: 'medium',
          timeStyle: 'short',
        },
      },
    },
    locales: {
      root: {
        label: '简体中文',
        lang: 'zh-CN',
        title: 'Oxpecker',
        description: '让 AI 生成的代码更容易验证',
        themeConfig: {
          nav: zhNav,
          sidebar: zhSidebar,
          outline: {
            label: '本页内容',
          },
          docFooter: {
            prev: '上一篇',
            next: '下一篇',
          },
          lastUpdated: {
            text: '最后更新',
            formatOptions: {
              dateStyle: 'medium',
              timeStyle: 'short',
            },
          },
        },
      },
      en: {
        label: 'English',
        lang: 'en-US',
        title: 'Oxpecker',
        description: 'Make AI-generated code easier to verify',
        themeConfig: {
          nav: enNav,
          sidebar: enSidebar,
          outline: {
            label: 'On this page',
          },
          docFooter: {
            prev: 'Previous page',
            next: 'Next page',
          },
          lastUpdated: {
            text: 'Last updated',
            formatOptions: {
              dateStyle: 'medium',
              timeStyle: 'short',
            },
          },
        },
      },
    },
    markdown: {
      config(md) {
        md.use(mathjax3)
        md.use(footnote)

        const inline = md.renderer.rules.math_inline
        const block = md.renderer.rules.math_block
        if (inline) {
          md.renderer.rules.math_inline = (...args) => stripStyle(inline(...args))
        }
        if (block) {
          md.renderer.rules.math_block = (...args) => stripStyle(block(...args))
        }

        md.renderer.rules.footnote_ref = (tokens, idx) => {
          const id = Number(tokens[idx].meta.id) + 1
          return `<sup class="footnote-ref"><a href="#fn${id}" id="fnref${id}">${id}</a></sup>`
        }

        registerContainer(md, 'expand', '展开')
        registerContainer(md, 'thinking', '思考')
        registerContainer(md, 'practice', '实践')
      },
    },
    vue: {
      template: {
        compilerOptions: {
          isCustomElement: (tag) => mathjaxTags.includes(tag),
        },
      },
    },
  }),
)
