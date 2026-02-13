'use client'

import { useState, useRef, useEffect } from 'react'
import styles from './page.module.css'

type Pipeline = 'agentic' | 'kalm' | 'qwen' | 'llama'

interface Diagnostics {
  loaded_from_cache: boolean
  model_load_ms: number
  gen_ms: number
  // Encoder/embedding fields (kalm pipeline only)
  encoder_loaded_from_cache?: boolean
  encoder_load_ms?: number
  embedding_ms?: number
  embedding_dim?: number
}

export default function Home() {
  const [inputText, setInputText] = useState('')
  const [result, setResult] = useState<string | null>(null)
  const [diagnostics, setDiagnostics] = useState<Diagnostics | null>(null)
  const [pipeline, setPipeline] = useState<Pipeline>('agentic')
  const [error, setError] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [isAnimating, setIsAnimating] = useState(false)
  const [copied, setCopied] = useState(false)
  const textareaRef = useRef<HTMLTextAreaElement>(null)

  // Copy to clipboard with fallback for HTTP
  const copyToClipboard = async (text: string) => {
    try {
      // Try modern clipboard API first (requires HTTPS)
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(text)
      } else {
        // Fallback for HTTP: use textarea + execCommand
        const textArea = document.createElement('textarea')
        textArea.value = text
        textArea.style.position = 'fixed'
        textArea.style.left = '-999999px'
        textArea.style.top = '-999999px'
        document.body.appendChild(textArea)
        textArea.focus()
        textArea.select()
        document.execCommand('copy')
        document.body.removeChild(textArea)
      }
      // Show feedback
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch (err) {
      console.error('Failed to copy:', err)
    }
  }

  useEffect(() => {
    // Auto-resize textarea
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto'
      textareaRef.current.style.height = `${Math.max(120, textareaRef.current.scrollHeight)}px`
    }
  }, [inputText])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    
    if (!inputText.trim()) {
      setError('Please enter some text')
      return
    }

    setIsLoading(true)
    setError(null)
    setResult(null)
    setDiagnostics(null)
    setIsAnimating(true)

    try {
      // Use AbortController with 5 minute timeout for model loading
      const controller = new AbortController()
      const timeoutId = setTimeout(() => controller.abort(), 300000) // 5 minutes
      
      const response = await fetch('/api/nl2sysml', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ 
          text: inputText,
          pipeline: pipeline,
          max_new_tokens: 4096
        }),
        signal: controller.signal,
      })
      
      clearTimeout(timeoutId)

      if (!response.ok) {
        const data = await response.json()
        throw new Error(data.detail || 'Request failed')
      }

      const data = await response.json()
      setResult(data.sysml)
      setDiagnostics(data.diagnostics)
    } catch (err) {
      if (err instanceof Error && err.name === 'AbortError') {
        setError('Request timed out. The model may still be loading - please try again.')
      } else {
        setError(err instanceof Error ? err.message : 'An error occurred')
      }
    } finally {
      setIsLoading(false)
      setTimeout(() => setIsAnimating(false), 300)
    }
  }

  const handleClear = () => {
    setInputText('')
    setResult(null)
    setDiagnostics(null)
    setError(null)
    textareaRef.current?.focus()
  }

  return (
    <main className={styles.main}>
      {/* Decorative grid */}
      <div className={styles.gridBg} aria-hidden="true" />
      
      <div className={styles.container}>
        {/* Header */}
        <header className={styles.header}>
          <div className={styles.logoWrapper}>
            <div className={styles.logoIcon}>
              <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M12 2L2 7L12 12L22 7L12 2Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                <path d="M2 17L12 22L22 17" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                <path d="M2 12L12 17L22 12" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </div>
            <h1 className={styles.title}>
              SysML<span className={styles.titleAccent}>-NL</span>
            </h1>
          </div>
          <p className={styles.subtitle}>
            Natural Language → SysML Converter
          </p>
          <div className={styles.badge}>
            <span className={styles.badgeDot} />
            v0.2
          </div>
        </header>

        {/* Main Card */}
        <div className={styles.card}>
          <form onSubmit={handleSubmit} className={styles.form}>
            {/* Pipeline Selection */}
            <div className={styles.pipelineSection}>
              <label className={styles.label}>
                <span className={styles.labelIcon}>⚙</span>
                Pipeline
              </label>
              <div className={styles.pipelineButtons}>
                {(['agentic', 'kalm', 'qwen', 'llama'] as Pipeline[]).map((p) => (
                  <button
                    key={p}
                    type="button"
                    className={`${styles.pipelineBtn} ${pipeline === p ? styles.pipelineBtnActive : ''}`}
                    onClick={() => setPipeline(p)}
                  >
                    {p.toUpperCase()}
                  </button>
                ))}
              </div>
            </div>

            {/* Input Section */}
            <div className={styles.inputSection}>
              <label className={styles.label}>
                <span className={styles.labelIcon}>❯</span>
                Input Natural Language
              </label>
              <div className={styles.textareaWrapper}>
                <textarea
                  ref={textareaRef}
                  value={inputText}
                  onChange={(e) => setInputText(e.target.value)}
                  placeholder="Describe your system in natural language..."
                  className={styles.textarea}
                  rows={4}
                />
                <div className={styles.textareaGlow} />
              </div>
              <div className={styles.inputMeta}>
                <span className={styles.charCount}>
                  {inputText.length} characters
                </span>
              </div>
            </div>

            {/* Actions */}
            <div className={styles.actions}>
              <button
                type="button"
                onClick={handleClear}
                className={styles.btnSecondary}
                disabled={isLoading}
              >
                Clear
              </button>
              <button
                type="submit"
                className={styles.btnPrimary}
                disabled={isLoading || !inputText.trim()}
              >
                {isLoading ? (
                  <>
                    <span className={styles.spinner} />
                    Converting...
                  </>
                ) : (
                  <>
                    Convert
                    <span className={styles.btnArrow}>→</span>
                  </>
                )}
              </button>
            </div>
          </form>

          {/* Result Section */}
          {(result || error) && (
            <div className={`${styles.resultSection} ${isAnimating ? styles.resultAnimating : ''}`}>
              <div className={styles.divider}>
                <span className={styles.dividerLine} />
                <span className={styles.dividerLabel}>Output</span>
                <span className={styles.dividerLine} />
              </div>
              
              {error ? (
                <div className={styles.errorBox}>
                  <span className={styles.errorIcon}>✕</span>
                  <span>{error}</span>
                </div>
              ) : result ? (
                <div className={styles.resultBox}>
                  <div className={styles.resultHeader}>
                    <span className={styles.resultLabel}>
                      <span className={styles.resultDot} />
                      SysML Output
                    </span>
                    <button 
                      className={`${styles.copyBtn} ${copied ? styles.copyBtnSuccess : ''}`}
                      onClick={() => copyToClipboard(result)}
                      title={copied ? "Copied!" : "Copy to clipboard"}
                    >
                      {copied ? (
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                          <polyline points="20 6 9 17 4 12"/>
                        </svg>
                      ) : (
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                          <rect x="9" y="9" width="13" height="13" rx="2" ry="2"/>
                          <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>
                        </svg>
                      )}
                    </button>
                  </div>
                  <pre className={styles.resultCode}>{result}</pre>
                  {diagnostics && (
                    <div className={styles.diagnostics}>
                      {diagnostics.model_load_ms > 0 && (
                        <span className={styles.diagItem}>⏱ load: {(diagnostics.model_load_ms / 1000).toFixed(1)}s</span>
                      )}
                      <span className={styles.diagItem}>⚡ gen: {(diagnostics.gen_ms / 1000).toFixed(1)}s</span>
                    </div>
                  )}
                </div>
              ) : null}
            </div>
          )}
        </div>

        {/* Footer */}
        <footer className={styles.footer}>
          <span>SysML-NL Converter</span>
          <span className={styles.footerDot}>•</span>
          <span>Powered by FastAPI + Next.js</span>
        </footer>
      </div>
    </main>
  )
}
