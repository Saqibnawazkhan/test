import { createContext, useContext, useEffect, useState } from 'react'

const UR = {
  Dashboard: 'ڈیش بورڈ', 'Knowledge Graph': 'نالج گراف', 'Entity Resolution': 'شناخت کی تطبیق',
  'Risk Analysis': 'خطرے کا تجزیہ', 'Audit Trail': 'آڈٹ ٹریل', Reports: 'رپورٹس',
  'All Records': 'تمام ریکارڈز', 'POS Verification': 'پی او ایس تصدیق', 'Tax Payments': 'ٹیکس ادائیگیاں',
  'Citizen Inbox': 'شہری ان باکس', Settings: 'ترتیبات', 'AI Assistant': 'اے آئی معاون',
  Home: 'مرکزی صفحہ', Logout: 'لاگ آؤٹ', Profile: 'پروفائل', 'Pay Tax': 'ٹیکس ادا کریں',
  'Tax Calculator': 'ٹیکس کیلکولیٹر', 'My Assets': 'میری جائیدادیں', 'Scan Receipt': 'رسید اسکین کریں',
  'My Score': 'میرا اسکور', Overview: 'جائزہ',
}

const Ctx = createContext(null)

export function AppProvider({ children }) {
  const [theme, setTheme] = useState(() => localStorage.getItem('tn_theme') || 'dark')
  const [lang, setLang] = useState(() => localStorage.getItem('tn_lang') || 'EN')
  // auth: { role: 'admin'|'citizen', cnic, name }
  const [auth, setAuth] = useState(() => {
    try { return JSON.parse(localStorage.getItem('tn_auth') || 'null') } catch { return null }
  })

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme)
    localStorage.setItem('tn_theme', theme)
  }, [theme])
  useEffect(() => {
    document.documentElement.setAttribute('dir', lang === 'UR' ? 'rtl' : 'ltr')
    localStorage.setItem('tn_lang', lang)
  }, [lang])
  useEffect(() => {
    if (auth) localStorage.setItem('tn_auth', JSON.stringify(auth))
    else localStorage.removeItem('tn_auth')
  }, [auth])

  const t = (s) => (lang === 'UR' ? UR[s] || s : s)
  const toggleTheme = () => setTheme((x) => (x === 'dark' ? 'light' : 'dark'))

  return (
    <Ctx.Provider value={{ theme, setTheme, toggleTheme, lang, setLang, t, auth, setAuth }}>
      {children}
    </Ctx.Provider>
  )
}

export const useApp = () => useContext(Ctx)
