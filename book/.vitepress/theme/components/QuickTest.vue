<script setup lang="ts">
import { computed, reactive } from 'vue'

type Option = {
  id: string
  text: string
  correct?: boolean
  explanation: string
}

type Question = {
  id: string
  type: 'single' | 'multiple'
  prompt: string
  options: Option[]
}

const props = defineProps<{
  questions: Question[]
}>()

const selected = reactive<Record<string, string[]>>({})
const submitted = reactive<Record<string, boolean>>({})

function ensure(question: Question): string[] {
  selected[question.id] ??= []
  return selected[question.id]
}

function isSelected(question: Question, option: Option): boolean {
  return ensure(question).includes(option.id)
}

function toggle(question: Question, option: Option) {
  const current = ensure(question)

  if (question.type === 'single') {
    selected[question.id] = [option.id]
    return
  }

  if (current.includes(option.id)) {
    selected[question.id] = current.filter((id) => id !== option.id)
  } else {
    selected[question.id] = [...current, option.id]
  }
}

function isAnswered(question: Question): boolean {
  return ensure(question).length > 0
}

function isCorrect(question: Question): boolean {
  const actual = new Set(ensure(question))
  const expected = new Set(question.options.filter((option) => option.correct).map((option) => option.id))

  if (actual.size !== expected.size) return false
  for (const id of actual) {
    if (!expected.has(id)) return false
  }
  return true
}

function submit(question: Question) {
  submitted[question.id] = true
}

function reset(question: Question) {
  selected[question.id] = []
  submitted[question.id] = false
}

const submittedQuestions = computed(() => props.questions.filter((question) => submitted[question.id]))
const correctCount = computed(() => submittedQuestions.value.filter((question) => isCorrect(question)).length)
</script>

<template>
  <section class="quick-test" aria-label="Quick test">
    <article v-for="(question, index) in questions" :key="question.id" class="quick-test__question">
      <div class="quick-test__prompt">
        <p>{{ index + 1 }}. {{ question.prompt }}</p>
      </div>

      <div class="quick-test__options">
        <button
          v-for="option in question.options"
          :key="option.id"
          type="button"
          class="quick-test__option"
          :class="{
            'is-selected': isSelected(question, option),
            'is-correct': submitted[question.id] && option.correct,
            'is-wrong': submitted[question.id] && isSelected(question, option) && !option.correct,
          }"
          :aria-pressed="isSelected(question, option)"
          @click="toggle(question, option)"
        >
          <span class="quick-test__control" aria-hidden="true">
            <span v-if="question.type === 'multiple'" class="quick-test__checkbox">
              <span v-if="isSelected(question, option)">✓</span>
            </span>
            <span v-else class="quick-test__radio">
              <span v-if="isSelected(question, option)"></span>
            </span>
          </span>
          <span class="quick-test__option-text">{{ option.text }}</span>
        </button>
      </div>

      <div v-if="submitted[question.id]" class="quick-test__feedback" :class="{ 'is-success': isCorrect(question) }">
        <p class="quick-test__result">
          {{ isCorrect(question) ? '回答正确。' : '还没有抓住这个概念。' }}
        </p>
        <ul>
          <li v-for="option in question.options" :key="option.id">
            <strong>{{ option.correct ? '正确项' : '误解项' }}：</strong>{{ option.explanation }}
          </li>
        </ul>
      </div>

      <div class="quick-test__actions">
        <button type="button" class="quick-test__submit" :disabled="!isAnswered(question)" @click="submit(question)">
          检查答案
        </button>
        <button type="button" class="quick-test__reset" @click="reset(question)">
          重做
        </button>
      </div>
    </article>

    <p v-if="submittedQuestions.length > 0" class="quick-test__summary">
      已完成 {{ submittedQuestions.length }} 题，答对 {{ correctCount }} 题。
    </p>
  </section>
</template>
