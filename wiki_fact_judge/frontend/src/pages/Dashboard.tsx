import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import ExecutionHistory from '../components/ExecutionHistory';
import { planApi, reportApi } from '../api';
import { TestPlan, TestReport } from '../types';
import '../App.css';

const Dashboard: React.FC = () => {
  const [plans, setPlans] = useState<TestPlan[]>([]);
  const [selectedPlanId, setSelectedPlanId] = useState<number | null>(null);
  const [recentReports, setRecentReports] = useState<TestReport[]>([]);
  const [loading, setLoading] = useState(true);

  // 初始化数据
  useEffect(() => {
    fetchData();
  }, []); // 只在组件挂载时执行一次

  const fetchData = async () => {
    try {
      setLoading(true);
      const [plansResponse, reportsResponse] = await Promise.all([
        planApi.getAllPlans(),
        reportApi.getAllReports("created_at_desc")
      ]);

      setPlans(plansResponse.data);
      setRecentReports(reportsResponse.data.slice(0, 5)); // 最近5个报告
    } catch (error) {
      console.error('Failed to fetch data:', error);
    } finally {
      setLoading(false);
    }
  };

  const handlePlanSelect = (planId: number) => {
    setSelectedPlanId(planId);
  };

  const closeHistory = () => {
    setSelectedPlanId(null);
  };

  return (
    <div className="dashboard">
      <div className="dashboard-content">
        <h2>Dashboard</h2>
        <p>Welcome to the Wiki Fact Judge System</p>

        <div className="quick-actions">
          <Link to="/cases" className="btn">Manage Cases</Link>
          <Link to="/plans" className="btn btn-secondary">Manage Plans</Link>
          <Link to="/reports" className="btn btn-secondary">View Reports</Link>
        </div>

        <div className="dashboard-stats">
          <div className="stat-card">
            <h3>{plans.length}</h3>
            <p>Total Plans</p>
          </div>
          <div className="stat-card">
            <h3>{recentReports.length}</h3>
            <p>Recent Reports</p>
          </div>
        </div>

        <div className="dashboard-section">
          <h3>Recent Reports</h3>
          {recentReports.length > 0 ? (
            <table className="table">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Name</th>
                  <th>Status</th>
                  <th>Score</th>
                  <th>Created</th>
                </tr>
              </thead>
              <tbody>
                {recentReports.map(report => {
                  return (
                    <tr key={report.id}>
                      <td>{report.id}</td>
                      <td>{report.report_name}</td>
                      <td>
                        <span className={`status-badge status-${report.status.toLowerCase()}`}>
                          {report.status}
                        </span>
                      </td>
                      <td>{report.final_score?.toFixed(2) || 'N/A'}</td>
                      <td>{new Date(report.created_at).toLocaleDateString()}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          ) : (
            <p>No recent reports available</p>
          )}
        </div>

        <div className="dashboard-section">
          <h3>View Plan Execution History</h3>
          <div className="plan-selector">
            <select
              value={selectedPlanId || ''}
              onChange={(e) => handlePlanSelect(Number(e.target.value))}
              disabled={loading}
            >
              <option value="">Select a plan to view execution history</option>
              {plans.map(plan => (
                <option key={plan.id} value={plan.id}>
                  {plan.name} (ID: {plan.id})
                </option>
              ))}
            </select>
          </div>

          {selectedPlanId && (
            <div className="execution-history-modal">
              <div className="modal-header">
                <h3>Execution History for Plan: {plans.find(p => p.id === selectedPlanId)?.name}</h3>
                <button className="close-btn" onClick={closeHistory}>×</button>
              </div>
              <ExecutionHistory planId={selectedPlanId} />
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default Dashboard;