import { useEffect, useRef, useState } from 'react'
import { I } from './Icons.jsx'
import { api } from '../lib/api.js'

// Grounded Claude assistant — talks to POST /chat (admin = person-specific, user = general FBR law).
export default function Assistant({ mode = 'user', cnic = '', onClose }) {
  const seed = mode === 'admin'
    ? 'Assalam-o-Alaikum. I am the TaxNet investigation copilot. Ask me about any citizen, cluster or compliance trend.'
    : 'Assalam-o-Alaikum. I can answer your tax questions under FBR law (FY 2025-26) and explain your assessment. Ask me anything.'
  const [msgs, setMsgs] = useState([{ from: 'ai', text: seed }])
  const [input, setInput] = useState('')
  const [typing, setTyping] = useState(false)
  const bodyRef = useRef()

  useEffect(() => { if (bodyRef.current) bodyRef.current.scrollTop = bodyRef.current.scrollHeight }, [msgs, typing])

  async function send(text) {
    const tmsg = (text || input).trim()
    if (!tmsg || typing) return
    const next = [...msgs, { from: 'user', text: tmsg }]
    setMsgs(next); setInput(''); setTyping(true)
    try {
      const payload = next.filter((m) => m.from !== 'sys').map((m) => ({ role: m.from === 'user' ? 'user' : 'assistant', content: m.text }))
      const r = await api.chat(payload, mode, cnic)
      setMsgs((m) => [...m, { from: 'ai', text: r.reply || r.message || '…' }])
    } catch (e) {
      setMsgs((m) => [...m, { from: 'ai', text: '⚠️ Could not reach the assistant. Ensure the backend is running and the Claude key has credits.' }])
    } finally { setTyping(false) }
  }

  const chips = mode === 'admin'
    ? ['Show new flags', 'Recovery potential', 'Draft a 122(5A) notice']
    : ['How much tax on 1.2M salary?', 'Is a gift from my father taxable?', 'What is the filer benefit?']

  return (
    <>
      <div className="drawer-scrim" onClick={onClose} />
      <div className="drawer">
        <div className="drawer-head">
          <div className="row" style={{ gap: 12 }}>
            <div style={{ width: 38, height: 38, borderRadius: 11, background: 'linear-gradient(135deg,var(--green),var(--blue))', display: 'grid', placeItems: 'center', color: '#04070D' }}>{I('bot')}</div>
            <div><div style={{ fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 15 }}>TaxNet Copilot</div><div className="row" style={{ fontSize: 11, color: 'var(--green)', gap: 6 }}><span className="dot-pulse" />grounded · Claude</div></div>
          </div>
          <button className="icon-btn" style={{ width: 32, height: 32 }} onClick={onClose}>{I('close')}</button>
        </div>
        <div className="drawer-body" ref={bodyRef} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          {msgs.map((m, i) => (
            <div key={i} style={{ display: 'flex', justifyContent: m.from === 'user' ? 'flex-end' : 'flex-start' }}>
              <div style={{ maxWidth: '84%', padding: '11px 14px', borderRadius: m.from === 'user' ? '14px 14px 4px 14px' : '14px 14px 14px 4px', fontSize: 13, lineHeight: 1.55, whiteSpace: 'pre-wrap',
                background: m.from === 'user' ? 'linear-gradient(135deg,var(--blue),#1E6FE0)' : 'var(--panel-2)', color: m.from === 'user' ? '#fff' : 'var(--text)', border: m.from === 'ai' ? '1px solid var(--panel-border)' : 'none' }}>{m.text}</div>
            </div>
          ))}
          {typing && <div className="row" style={{ gap: 5, padding: '11px 14px', background: 'var(--panel-2)', borderRadius: 14, width: 'fit-content', border: '1px solid var(--panel-border)' }}>
            {[0, 1, 2].map((i) => <span key={i} style={{ width: 6, height: 6, borderRadius: '50%', background: 'var(--text-3)', animation: `blink 1.2s ${i * 0.2}s infinite` }} />)}
          </div>}
        </div>
        <div style={{ padding: '12px 16px 8px', display: 'flex', gap: 7, flexWrap: 'wrap' }}>
          {chips.map((c) => <button key={c} onClick={() => send(c)} style={{ fontSize: 11.5, padding: '6px 11px', borderRadius: 8, border: '1px solid var(--panel-border)', background: 'var(--panel)', color: 'var(--text-2)', cursor: 'pointer' }}>{c}</button>)}
        </div>
        <div style={{ padding: '8px 16px 18px', display: 'flex', gap: 10, alignItems: 'center' }}>
          <div className="search-box" style={{ flex: 1, maxWidth: 'none' }}>
            <input value={input} onChange={(e) => setInput(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && send()} placeholder="Ask the copilot…" />
          </div>
          <button className="btn btn-primary" style={{ padding: '11px 13px' }} onClick={() => send()}>{I('send')}</button>
        </div>
        <style>{`@keyframes blink{0%,60%,100%{opacity:.25;transform:translateY(0)}30%{opacity:1;transform:translateY(-3px)}}`}</style>
      </div>
    </>
  )
}
