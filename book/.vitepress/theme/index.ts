import DefaultTheme from 'vitepress/theme'
import QuickTest from './components/QuickTest.vue'
import './custom.css'

export default {
  extends: DefaultTheme,
  enhanceApp({ app }) {
    app.component('QuickTest', QuickTest)
  },
}
