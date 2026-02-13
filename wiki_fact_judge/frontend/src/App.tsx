import React from 'react';
import { BrowserRouter as Router, Routes, Route, Link } from 'react-router-dom';
import CasesPage from './pages/CasesPage';
import PlansPage from './pages/PlansPage';
import ReportsPage from './pages/ReportsPage';
import Dashboard from './pages/Dashboard';
import './App.css';

function App() {
  return (
    <Router>
      <div className="App">
        <nav className="navbar">
          <div className="container">
            <h1>
              <Link to="/" style={{ textDecoration: 'none', color: 'inherit' }}>
                <span className="home-icon">🏠</span> Wiki Fact Judge
              </Link>
            </h1>
            <ul className="nav-links">
              <li><Link to="/">Home</Link></li>
              <li><Link to="/cases">Cases</Link></li>
              <li><Link to="/plans">Plans</Link></li>
              <li><Link to="/reports">Reports</Link></li>
            </ul>
          </div>
        </nav>

        <main className="main-content">
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/cases/*" element={<CasesPage />} />
            <Route path="/plans/*" element={<PlansPage />} />
            <Route path="/reports/*" element={<ReportsPage />} />
          </Routes>
        </main>
      </div>
    </Router>
  );
}

export default App;