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

export default withMermaid(
  defineConfig({
    title: 'Formal Verification Booklet',
    description: '从系统工程视角学习 formal verification 的小书',
    lang: 'zh-CN',
    base: '/',
    cleanUrls: true,
    lastUpdated: true,
    themeConfig: {
      logo: '/fv.svg',
      nav: [
        { text: '序言', link: '/prologue' },
        { text: '入门', link: '/foundations/01-why-formal-verification' },
      ],
      sidebar: [
        {
          text: '开始',
          items: [
            { text: '序言', link: '/prologue' },
          ],
        },
        {
          text: 'Formal Verification 入门',
          items: [
            { text: '为什么需要形式化验证', link: '/foundations/01-why-formal-verification' },
            { text: '历史背景和知识地图', link: '/foundations/02-history-and-map' },
          ],
        },
      ],
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
