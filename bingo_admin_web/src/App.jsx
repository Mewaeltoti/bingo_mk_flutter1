import React from 'react';
import { BrowserRouter as Router, Routes, Route, Link } from 'react-router-dom';
import Dashboard from './pages/dashboard';
import GameControl from './pages/gameControl';
import Players from './pages/players';
import Finance from './pages/finance';
import './App.css';

function App() {
  return (
    <Router>
      <div style={{ display: 'flex', height: '100vh', fontFamily: 'sans-serif' }}>
        {/* Sidebar */}
        <div style={{ width: '250px', backgroundColor: '#1e1e2f', color: 'white', padding: '20px' }}>
          <h2 style={{ color: '#61dafb', marginBottom: '30px' }}>Bingo Admin</h2>
          <nav style={{ display: 'flex', flexDirection: 'column', gap: '15px' }}>
            <Link to="/" style={{ color: 'white', textDecoration: 'none', fontSize: '18px' }}>Live Dashboard</Link>
            <Link to="/control" style={{ color: 'white', textDecoration: 'none', fontSize: '18px' }}>Game Control</Link>
            <Link to="/players" style={{ color: 'white', textDecoration: 'none', fontSize: '18px' }}>Players</Link>
            <Link to="/finance" style={{ color: 'white', textDecoration: 'none', fontSize: '18px' }}>Finance</Link>
          </nav>
        </div>

        {/* Main Content Area */}
        <div style={{ flex: 1, padding: '30px', backgroundColor: '#f4f6f8', overflowY: 'auto' }}>
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/control" element={<GameControl />} />
            <Route path="/players" element={<Players />} />
            <Route path="/finance" element={<Finance />} />
          </Routes>
        </div>
      </div>
    </Router>
  );
}

export default App;
