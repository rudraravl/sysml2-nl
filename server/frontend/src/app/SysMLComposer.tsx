'use client'

import { useState, useRef, useEffect } from 'react'
import styles from './page.module.css'

interface ComposerCtx {
  app_name: string
  actors_lines: string
  requirements_lines: string
  blocks_lines: string
  usecases_lines: string
  elements_filename: string
}

const defaultCtx: ComposerCtx = {
  app_name: '',
  actors_lines: '',
  requirements_lines: '',
  blocks_lines: '',
  usecases_lines: '',
  elements_filename: '',
}

function buildFormData(ctx: ComposerCtx): FormData {
  const fd = new FormData()
  fd.append('app_name', ctx.app_name)
  fd.append('actors_lines', ctx.actors_lines)
  fd.append('requirements_lines', ctx.requirements_lines)
  fd.append('blocks_lines', ctx.blocks_lines)
  fd.append('usecases_lines', ctx.usecases_lines)
  fd.append('elements_filename', ctx.elements_filename)
  return fd
}

function triggerDownload(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}

export default function SysMLComposer() {
  const [ctx, setCtx] = useState<ComposerCtx>(defaultCtx)
  const [sysmlText, setSysmlText] = useState<string | null>(null)
  const [diagramId, setDiagramId] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [message, setMessage] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [dotAvailable, setDotAvailable] = useState<boolean | null>(null)
  const sysmlFileRef = useRef<HTMLInputElement>(null)
  const jsonFileRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    fetch('/api/sysml-composer/dot-available')
      .then((r) => r.json())
      .then((d) => setDotAvailable(d.available))
      .catch(() => setDotAvailable(false))
  }, [])

  const clearMessage = () => {
    setMessage(null)
    setError(null)
  }

  const handleBack = () => {
    setSysmlText(null)
    setDiagramId(null)
    clearMessage()
  }

  const handlePreview = async () => {
    setIsLoading(true)
    setError(null)
    setSysmlText(null)
    setDiagramId(null)
    try {
      const r = await fetch('/api/sysml-composer/preview', {
        method: 'POST',
        body: buildFormData(ctx),
      })
      if (!r.ok) {
        const d = await r.json().catch(() => ({}))
        throw new Error(d.detail || 'Preview failed')
      }
      const d = await r.json()
      setSysmlText(d.sysml_text)
      if (d.ctx) setCtx(d.ctx)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Preview failed')
    } finally {
      setIsLoading(false)
    }
  }

  const handleDiagramPng = async () => {
    if (!dotAvailable) {
      setError("Graphviz 'dot' is not available. Cannot generate diagram.")
      return
    }
    setIsLoading(true)
    setError(null)
    setSysmlText(null)
    try {
      const r = await fetch('/api/sysml-composer/diagram-png', {
        method: 'POST',
        body: buildFormData(ctx),
      })
      if (!r.ok) {
        const d = await r.json().catch(() => ({}))
        throw new Error(d.detail || 'Diagram generation failed')
      }
      const d = await r.json()
      setDiagramId(d.diagram_id)
      if (d.ctx) setCtx(d.ctx)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Diagram generation failed')
    } finally {
      setIsLoading(false)
    }
  }

  const handleDiagramPdf = async () => {
    if (!dotAvailable) {
      setError("Graphviz 'dot' is not available. Cannot generate diagram.")
      return
    }
    setIsLoading(true)
    setError(null)
    try {
      const r = await fetch('/api/sysml-composer/diagram-pdf', {
        method: 'POST',
        body: buildFormData(ctx),
      })
      if (!r.ok) {
        const d = await r.json().catch(() => ({}))
        throw new Error(d.detail || 'PDF generation failed')
      }
      const blob = await r.blob()
      const cd = r.headers.get('Content-Disposition')
      const match = cd?.match(/filename="?([^";]+)"?/)
      const fname = match ? match[1] : `${ctx.app_name || 'diagram'}.pdf`
      triggerDownload(blob, fname)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'PDF generation failed')
    } finally {
      setIsLoading(false)
    }
  }

  const handleDownloadSysml = async () => {
    setIsLoading(true)
    setError(null)
    try {
      const r = await fetch('/api/sysml-composer/download-sysml', {
        method: 'POST',
        body: buildFormData(ctx),
      })
      if (!r.ok) throw new Error('Download failed')
      const blob = await r.blob()
      const cd = r.headers.get('Content-Disposition')
      const match = cd?.match(/filename="?([^";]+)"?/)
      const fname = match ? match[1] : `${ctx.app_name || 'model'}.sysml`
      triggerDownload(blob, fname)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Download failed')
    } finally {
      setIsLoading(false)
    }
  }

  const handleDownloadJson = async () => {
    setIsLoading(true)
    setError(null)
    try {
      const fd = buildFormData(ctx)
      const r = await fetch('/api/sysml-composer/download-json', {
        method: 'POST',
        body: fd,
      })
      if (!r.ok) throw new Error('Download failed')
      const blob = await r.blob()
      const cd = r.headers.get('Content-Disposition')
      const match = cd?.match(/filename="?([^";]+)"?/)
      const fname = match ? match[1] : `${ctx.app_name || 'elements'}.json`
      triggerDownload(blob, fname)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Download failed')
    } finally {
      setIsLoading(false)
    }
  }

  const handleLoadSysml = async () => {
    const input = sysmlFileRef.current
    if (!input?.files?.length) {
      setError('No .sysml file selected.')
      return
    }
    const file = input.files[0]
    const fd = new FormData()
    fd.append('file', file)
    setIsLoading(true)
    setError(null)
    setMessage(null)
    try {
      const r = await fetch('/api/sysml-composer/load-sysml', {
        method: 'POST',
        body: fd,
      })
      if (!r.ok) {
        const d = await r.json().catch(() => ({}))
        throw new Error(d.detail || 'Load failed')
      }
      const d = await r.json()
      setCtx(d.ctx)
      setMessage(d.message || 'SysML file loaded.')
      setSysmlText(null)
      setDiagramId(null)
      input.value = ''
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Load failed')
    } finally {
      setIsLoading(false)
    }
  }

  const handleLoadJson = async () => {
    const input = jsonFileRef.current
    if (!input?.files?.length) {
      setError('No JSON file selected.')
      return
    }
    const file = input.files[0]
    const fd = new FormData()
    fd.append('file', file)
    setIsLoading(true)
    setError(null)
    setMessage(null)
    try {
      const r = await fetch('/api/sysml-composer/load-json', {
        method: 'POST',
        body: fd,
      })
      if (!r.ok) {
        const d = await r.json().catch(() => ({}))
        throw new Error(d.detail || 'Load failed')
      }
      const d = await r.json()
      setCtx(d.ctx)
      setMessage(d.message || 'Elements loaded from JSON.')
      setSysmlText(null)
      setDiagramId(null)
      input.value = ''
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Load failed')
    } finally {
      setIsLoading(false)
    }
  }

  const showForm = !sysmlText && !diagramId

  return (
    <div className={styles.composerCard}>
      <h2 className={styles.composerTitle}>Structured SysML Composer</h2>
      <p className={styles.composerSubtitle}>
        Enter app name and elements below. Use the examples as guidance. Lines starting with # are ignored.
      </p>

      {dotAvailable === false && (
        <div className={styles.flashBox} style={{ background: 'rgba(249, 38, 114, 0.1)', borderColor: 'rgba(249, 38, 114, 0.3)', color: 'var(--accent-pink)' }}>
          Graphviz (dot) is not available. Diagram PNG/PDF generation is disabled. Install Graphviz to enable.
        </div>
      )}

      {(error || message) && (
        <div className={`${styles.flashBox} ${error ? styles.flashError : styles.flashInfo}`}>
          {error || message}
        </div>
      )}

      {showForm ? (
        <form
          className={styles.composerForm}
          onSubmit={(e) => {
            e.preventDefault()
            handlePreview()
          }}
        >
          <div className={styles.composerField}>
            <label className={styles.composerLabel}>App name</label>
            <input
              type="text"
              name="app_name"
              value={ctx.app_name}
              onChange={(e) => setCtx({ ...ctx, app_name: e.target.value })}
              placeholder="MySystem"
              className={styles.composerInput}
            />
          </div>

          <div className={styles.composerGrid}>
            <div className={styles.composerField}>
              <label className={styles.composerLabel}>Actors (one per line)</label>
              <textarea
                name="actors_lines"
                value={ctx.actors_lines}
                onChange={(e) => setCtx({ ...ctx, actors_lines: e.target.value })}
                placeholder="Operator&#10;Sensor"
                className={styles.composerTextarea}
                rows={4}
              />
              <div className={styles.composerExample}>Operator<br />Sensor</div>
            </div>
            <div className={styles.composerField}>
              <label className={styles.composerLabel}>Requirements (ID | text)</label>
              <textarea
                name="requirements_lines"
                value={ctx.requirements_lines}
                onChange={(e) => setCtx({ ...ctx, requirements_lines: e.target.value })}
                placeholder="R-001 | The system shall start within 5 seconds."
                className={styles.composerTextarea}
                rows={4}
              />
              <div className={styles.composerExample}>
                R-001 | The system shall start within 5 seconds.<br />
                R-002 | The operator shall be notified on fault.
              </div>
            </div>
          </div>

          <div className={styles.composerGrid}>
            <div className={styles.composerField}>
              <label className={styles.composerLabel}>Blocks (Name | attr1:type | part1, part2)</label>
              <textarea
                name="blocks_lines"
                value={ctx.blocks_lines}
                onChange={(e) => setCtx({ ...ctx, blocks_lines: e.target.value })}
                placeholder="Controller | state:string, version:int | cpu, memory"
                className={styles.composerTextarea}
                rows={4}
              />
              <div className={styles.composerExample}>
                Controller | state:string, version:int | cpu, memory<br />
                Sensor | reading:float |
              </div>
            </div>
            <div className={styles.composerField}>
              <label className={styles.composerLabel}>Use Cases (Name | SubjectBlock | actor1, actor2)</label>
              <textarea
                name="usecases_lines"
                value={ctx.usecases_lines}
                onChange={(e) => setCtx({ ...ctx, usecases_lines: e.target.value })}
                placeholder="StartSystem | Controller | Operator"
                className={styles.composerTextarea}
                rows={4}
              />
              <div className={styles.composerExample}>
                StartSystem | Controller | Operator<br />
                ReadSensor | Sensor | Operator
              </div>
            </div>
          </div>

          <div className={styles.composerActions}>
            <button type="button" onClick={handlePreview} disabled={isLoading} className={styles.btnPrimary}>
              {isLoading ? <><span className={styles.spinner} />Generating...</> : 'Generate SysML Preview'}
            </button>
            <button type="button" onClick={handleDiagramPng} disabled={isLoading || !dotAvailable} className={styles.btnPrimary}>
              Generate Diagram PNG
            </button>
            <button type="button" onClick={handleDiagramPdf} disabled={isLoading || !dotAvailable} className={styles.btnPrimary}>
              Generate Diagram PDF
            </button>
            <button type="button" onClick={handleDownloadSysml} disabled={isLoading} className={styles.btnSuccess}>
              Download .sysml
            </button>
            <div className={styles.composerJsonRow}>
              <button type="button" onClick={handleDownloadJson} disabled={isLoading} className={styles.btnSuccess}>
                Download All Elements JSON
              </button>
              <label className={styles.composerFilenameLabel}>Filename:</label>
              <input
                type="text"
                value={ctx.elements_filename}
                onChange={(e) => setCtx({ ...ctx, elements_filename: e.target.value })}
                placeholder="elements.json"
                className={styles.composerFilenameInput}
              />
            </div>
          </div>

          <div className={styles.composerLoadRow}>
            <div className={styles.composerFileGroup}>
              <label className={styles.composerFilenameLabel}>Load .sysml file:</label>
              <input ref={sysmlFileRef} type="file" accept=".sysml,.txt" className={styles.composerFileInput} />
              <button type="button" onClick={handleLoadSysml} disabled={isLoading} className={styles.btnSecondary}>
                Load SysML
              </button>
            </div>
            <div className={styles.composerFileGroup}>
              <label className={styles.composerFilenameLabel}>Load JSON:</label>
              <input ref={jsonFileRef} type="file" accept=".json" className={styles.composerFileInput} />
              <button type="button" onClick={handleLoadJson} disabled={isLoading} className={styles.btnSecondary}>
                Load All Elements
              </button>
            </div>
          </div>
        </form>
      ) : null}

      {sysmlText && (
        <>
          <div className={styles.composerPreview}>
            <pre>{sysmlText}</pre>
          </div>
          <button type="button" onClick={handleBack} className={styles.btnSecondary}>
            ← Back
          </button>
        </>
      )}

      {diagramId && (
        <>
          <div className={styles.composerDiagram}>
            <img src={`/api/sysml-composer/diagram/${diagramId}`} alt="SysML Diagram" />
          </div>
          <div className={styles.composerDiagramActions}>
            <a href={`/api/sysml-composer/diagram/${diagramId}`} download="diagram.png" className={styles.btnSuccess}>
              Download PNG
            </a>
            <button type="button" onClick={handleBack} className={styles.btnSecondary}>
              ← Back
            </button>
          </div>
        </>
      )}
    </div>
  )
}
