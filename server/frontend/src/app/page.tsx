'use client'

import { useState, useRef, useEffect } from 'react'
import styles from './page.module.css'

export default function Home() {
  const [inputText, setInputText] = useState('')
  const [result, setResult] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [isAnimating, setIsAnimating] = useState(false)
  const textareaRef = useRef<HTMLTextAreaElement>(null)

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
    setIsAnimating(true)

    try {
      const response = await fetch('/api/nl2llm', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ text: inputText }),
      })

      if (!response.ok) {
        const data = await response.json()
        throw new Error(data.detail || 'Request failed')
      }

      const data = await response.json()
      setResult(data.result)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred')
    } finally {
      setIsLoading(false)
      setTimeout(() => setIsAnimating(false), 300)
    }
  }

  const handleClear = () => {
    setInputText('')
    setResult(null)
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
            MVP v0.1
          </div>
        </header>

        {/* Main Card */}
        <div className={styles.card}>
          <form onSubmit={handleSubmit} className={styles.form}>
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
                      className={styles.copyBtn}
                      onClick={() => navigator.clipboard.writeText(result)}
                      title="Copy to clipboard"
                    >
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <rect x="9" y="9" width="13" height="13" rx="2" ry="2"/>
                        <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>
                      </svg>
                    </button>
                  </div>
                  <pre className={styles.resultCode}>{result}</pre>
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
