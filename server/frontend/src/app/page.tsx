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
  // Agentic pipeline fields
  experts_ms?: number
  synth_ms?: number
  rag_ms?: number
  num_candidates?: number
  expert_models?: string[]
  expert_times?: Record<string, number>
}

// Human-readable progress messages
const PROGRESS_MESSAGES: Record<string, string> = {
  'rag': 'Building knowledge context...',
  'rag_done': 'Context ready',
  'experts': 'Querying expert models...',
  'expert_done': 'Expert responded',
  'expert_failed': 'Expert unavailable',
  'experts_done': 'All experts responded',
  'synthesis': 'Synthesizing final result...',
  'done': 'Complete!',
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
  const [progressMsg, setProgressMsg] = useState<string>('')
  const [progressDetail, setProgressDetail] = useState<string>('')
  const [showArchitecture, setShowArchitecture] = useState(false)
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

  // Handle streaming request for agentic pipeline
  const handleAgenticStream = async () => {
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 300000) // 5 minutes

    try {
      const response = await fetch('/api/nl2sysml/stream', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          text: inputText,
          pipeline: 'agentic',
          max_new_tokens: 4096
        }),
        signal: controller.signal,
      })

      clearTimeout(timeoutId)

      if (!response.ok) {
        const data = await response.json()
        throw new Error(data.detail || 'Request failed')
      }

      const reader = response.body?.getReader()
      if (!reader) throw new Error('No response stream')

      const decoder = new TextDecoder()
      let buffer = ''

      while (true) {
        const { done, value } = await reader.read()
        if (done) break

        buffer += decoder.decode(value, { stream: true })
        
        // Process SSE events
        const lines = buffer.split('\n\n')
        buffer = lines.pop() || ''

        for (const line of lines) {
          if (line.startsWith('data: ')) {
            try {
              const data = JSON.parse(line.slice(6))
              
              if (data.type === 'progress') {
                const msg = PROGRESS_MESSAGES[data.stage] || data.stage
                setProgressMsg(msg)
                setProgressDetail(data.detail || '')
              } else if (data.type === 'result') {
                setResult(data.sysml)
                setDiagnostics(data.diagnostics)
                setProgressMsg('')
                setProgressDetail('')
              } else if (data.type === 'error') {
                throw new Error(data.message)
              }
              // Ignore heartbeat messages
            } catch (parseErr) {
              // Ignore parse errors
            }
          }
        }
      }
    } finally {
      clearTimeout(timeoutId)
    }
  }

  // Handle regular (non-streaming) request
  const handleRegularRequest = async () => {
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 300000) // 5 minutes
    
    try {
      const response = await fetch('/api/nl2sysml', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
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
    } finally {
      clearTimeout(timeoutId)
    }
  }

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
    setProgressMsg('')
    setProgressDetail('')
    setIsAnimating(true)

    try {
      // Use streaming for agentic pipeline to show progress
      if (pipeline === 'agentic') {
        await handleAgenticStream()
      } else {
        await handleRegularRequest()
      }
    } catch (err) {
      if (err instanceof Error && err.name === 'AbortError') {
        setError('Request timed out. The model may still be loading - please try again.')
      } else {
        setError(err instanceof Error ? err.message : 'An error occurred')
      }
    } finally {
      setIsLoading(false)
      setProgressMsg('')
      setProgressDetail('')
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
          <button 
            className={styles.archBtn}
            onClick={() => setShowArchitecture(true)}
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className={styles.archIcon}>
              <rect x="3" y="3" width="7" height="7" rx="1"/>
              <rect x="14" y="3" width="7" height="7" rx="1"/>
              <rect x="3" y="14" width="7" height="7" rx="1"/>
              <rect x="14" y="14" width="7" height="7" rx="1"/>
              <path d="M10 6.5h4M6.5 10v4M17.5 10v4M10 17.5h4"/>
            </svg>
            Architecture
          </button>
        </header>

        {/* Architecture Modal */}
        {showArchitecture && (
          <div className={styles.modalOverlay} onClick={() => setShowArchitecture(false)}>
            <div className={styles.modal} onClick={(e) => e.stopPropagation()}>
              <div className={styles.modalHeader}>
                <h2 className={styles.modalTitle}>Agentic Pipeline Architecture</h2>
                <button className={styles.modalClose} onClick={() => setShowArchitecture(false)}>
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M18 6L6 18M6 6l12 12"/>
                  </svg>
                </button>
              </div>
              <div className={styles.modalBody}>
                {/* Pipeline Flow Diagram */}
                <div className={styles.pipelineFlow}>
                  {/* Step 1: Input */}
                  <div className={styles.pipelineStep}>
                    <div className={styles.stepNumber}>1</div>
                    <div className={styles.stepBox}>
                      <div className={styles.stepIcon}>
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                          <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
                          <polyline points="14 2 14 8 20 8"/>
                          <line x1="16" y1="13" x2="8" y2="13"/>
                          <line x1="16" y1="17" x2="8" y2="17"/>
                        </svg>
                      </div>
                      <div className={styles.stepContent}>
                        <h3>Input</h3>
                        <p>Natural language requirement description</p>
                      </div>
                    </div>
                  </div>
                  
                  <div className={styles.pipelineArrow}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <path d="M12 5v14M19 12l-7 7-7-7"/>
                    </svg>
                  </div>

                  {/* Step 2: Input Agent (Coming Soon) */}
                  <div className={`${styles.pipelineStep} ${styles.stepComingSoon}`}>
                    <div className={styles.stepNumber}>2</div>
                    <div className={styles.stepBox}>
                      <div className={styles.stepIcon}>
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                          <circle cx="12" cy="12" r="10"/>
                          <path d="M12 16v-4M12 8h.01"/>
                        </svg>
                      </div>
                      <div className={styles.stepContent}>
                        <h3>Input Agent <span className={styles.comingSoonBadge}>Coming Soon</span></h3>
                        <p>Refines input, performs semantic search, and extracts key requirements</p>
                      </div>
                    </div>
                  </div>
                  
                  <div className={styles.pipelineArrow}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <path d="M12 5v14M19 12l-7 7-7-7"/>
                    </svg>
                  </div>

                  {/* Step 3: RAG */}
                  <div className={styles.pipelineStep}>
                    <div className={styles.stepNumber}>3</div>
                    <div className={styles.stepBox}>
                      <div className={styles.stepIcon}>
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                          <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/>
                          <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>
                          <circle cx="12" cy="10" r="3"/>
                        </svg>
                      </div>
                      <div className={styles.stepContent}>
                        <h3>RAG (Retrieval-Augmented Generation)</h3>
                        <p>Retrieves relevant examples from dataset and SysML v2 specification chunks</p>
                      </div>
                    </div>
                  </div>
                  
                  <div className={styles.pipelineArrow}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <path d="M12 5v14M19 12l-7 7-7-7"/>
                    </svg>
                  </div>

                  {/* Step 4: MoE */}
                  <div className={styles.pipelineStep}>
                    <div className={styles.stepNumber}>4</div>
                    <div className={styles.stepBox}>
                      <div className={styles.stepIcon}>
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                          <circle cx="6" cy="6" r="3"/>
                          <circle cx="18" cy="6" r="3"/>
                          <circle cx="6" cy="18" r="3"/>
                          <circle cx="18" cy="18" r="3"/>
                          <path d="M6 9v6M18 9v6M9 6h6M9 18h6"/>
                        </svg>
                      </div>
                      <div className={styles.stepContent}>
                        <h3>MoE (Mixture of Experts)</h3>
                        <p>Queries multiple LLMs in parallel: Gemini, GPT-4o, Claude, Llama</p>
                        <div className={styles.expertList}>
                          <span className={styles.expertTag}>gemini-3-pro</span>
                          <span className={styles.expertTag}>gpt-4o</span>
                          <span className={styles.expertTag}>claude-sonnet-4.5</span>
                          <span className={styles.expertTag}>llama-4-maverick</span>
                        </div>
                      </div>
                    </div>
                  </div>
                  
                  <div className={styles.pipelineArrow}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <path d="M12 5v14M19 12l-7 7-7-7"/>
                    </svg>
                  </div>

                  {/* Step 5: Synthesis */}
                  <div className={styles.pipelineStep}>
                    <div className={styles.stepNumber}>5</div>
                    <div className={styles.stepBox}>
                      <div className={styles.stepIcon}>
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                          <polygon points="12 2 2 7 12 12 22 7 12 2"/>
                          <polyline points="2 17 12 22 22 17"/>
                          <polyline points="2 12 12 17 22 12"/>
                        </svg>
                      </div>
                      <div className={styles.stepContent}>
                        <h3>Synthesis (Combiner)</h3>
                        <p>Claude synthesizes the best SysML model from all expert candidates</p>
                      </div>
                    </div>
                  </div>
                  
                  <div className={styles.pipelineArrow}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <path d="M12 5v14M19 12l-7 7-7-7"/>
                    </svg>
                  </div>

                  {/* Step 6: Compiler Feedback */}
                  <div className={styles.pipelineStep}>
                    <div className={styles.stepNumber}>6</div>
                    <div className={styles.stepBox}>
                      <div className={styles.stepIcon}>
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                          <polyline points="16 18 22 12 16 6"/>
                          <polyline points="8 6 2 12 8 18"/>
                          <line x1="12" y1="2" x2="12" y2="22"/>
                        </svg>
                      </div>
                      <div className={styles.stepContent}>
                        <h3>Compiler Feedback & Refinement</h3>
                        <p>Validates syntax with SysML v2 compiler, iteratively refines errors</p>
                        <div className={styles.refinementLoop}>
                          <span>Check</span>
                          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                            <path d="M5 12h14M12 5l7 7-7 7"/>
                          </svg>
                          <span>Fix</span>
                          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                            <path d="M5 12h14M12 5l7 7-7 7"/>
                          </svg>
                          <span>Repeat</span>
                        </div>
                      </div>
                    </div>
                  </div>
                  
                  <div className={styles.pipelineArrow}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <path d="M12 5v14M19 12l-7 7-7-7"/>
                    </svg>
                  </div>

                  {/* Step 7: Output */}
                  <div className={`${styles.pipelineStep} ${styles.stepFinal}`}>
                    <div className={styles.stepNumber}>7</div>
                    <div className={styles.stepBox}>
                      <div className={styles.stepIcon}>
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                          <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
                          <polyline points="22 4 12 14.01 9 11.01"/>
                        </svg>
                      </div>
                      <div className={styles.stepContent}>
                        <h3>Output</h3>
                        <p>Valid SysML v2 model ready for use</p>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

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

            {/* Progress indicator for agentic pipeline */}
            {isLoading && progressMsg && (
              <div className={styles.progressSection}>
                <div className={styles.progressBar}>
                  <div className={styles.progressBarInner} />
                </div>
                <div className={styles.progressText}>
                  <span className={styles.progressMsg}>{progressMsg}</span>
                  {progressDetail && (
                    <span className={styles.progressDetail}>{progressDetail}</span>
                  )}
                </div>
              </div>
            )}
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
