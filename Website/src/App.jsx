import { Routes, Route, Navigate } from 'react-router-dom'
import Landing from './pages/Landing.jsx'
import AdminShell from './pages/admin/AdminShell.jsx'
import CitizenShell from './pages/citizen/CitizenShell.jsx'
import Login from './pages/Login.jsx'

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<Landing />} />
      <Route path="/login" element={<Login />} />
      <Route path="/admin/*" element={<AdminShell />} />
      <Route path="/app/*" element={<CitizenShell />} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}
