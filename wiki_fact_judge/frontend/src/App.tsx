import React from 'react';
import { BrowserRouter as Router, Routes, Route, Link } from 'react-router-dom';
import CasesPage from './pages/CasesPage';
import PlansPage from './pages/PlansPage';
import ReportsPage from './pages/ReportsPage';
import './App.css';

function App() {
  return (
    <Router>
      <div className="App">
        <nav className="navbar">
          <div className="container">
            <h1>
              <Link to="/" style={{ textDecoration: 'none', color: 'inherit' }}>
                Wiki Fact Judge
              </Link>
            </h1>
            <ul className="nav-links">
              <li><Link to="/cases">Cases</Link></li>
              <li><Link to="/plans">Plans</Link></li>
              <li><Link to="/reports">Reports</Link></li>
            </ul>
          </div>
        </nav>

        <main className="main-content">
          <Routes>
            <Route path="/" element={
              <div className="dashboard">
                <h2>Dashboard</h2>
                <p>Welcome to the Wiki Fact Judge System</p>
                <div className="quick-actions">
                  <Link to="/cases" className="btn">Manage Cases</Link>
                  <Link to="/plans" className="btn btn-secondary">Manage Plans</Link>
                  <Link to="/reports" className="btn btn-secondary">View Reports</Link>
                </div>
              </div>
            } />
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