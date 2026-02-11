import React, { useState, useEffect } from 'react';
import { reportApi } from '../api';
import { TestReport } from '../types';
import ReportList from '../components/ReportList';
import ReportDetail from '../components/ReportDetail';
import { useParams, useNavigate, Routes, Route } from 'react-router-dom';

const ReportsPage: React.FC = () => {
  const [reports, setReports] = useState<TestReport[]>([]);
  const [selectedReport, setSelectedReport] = useState<TestReport | null>(null);
  const [loading, setLoading] = useState(true);
  const { reportId } = useParams<{ reportId?: string }>();
  const navigate = useNavigate();

  useEffect(() => {
    fetchReports();
  }, []);

  useEffect(() => {
    if (reportId) {
      const numericReportId = parseInt(reportId, 10);
      const selected = reports.find(r => r.id === numericReportId);
      setSelectedReport(selected || null);
    } else {
      setSelectedReport(null);
    }
  }, [reportId, reports]);

  const fetchReports = async () => {
    try {
      setLoading(true);
      const response = await reportApi.getAllReports();
      setReports(response.data);
    } catch (error) {
      console.error('Failed to fetch reports:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteReport = async (reportId: number) => {
    if (!window.confirm(`Are you sure you want to delete report ${reportId}?`)) {
      return;
    }

    try {
      await reportApi.deleteReport(reportId);
      alert(`Report ${reportId} deleted successfully`);
      // 刷新报告列表
      fetchReports();
      if (selectedReport?.id === reportId) {
        setSelectedReport(null);
        navigate('/reports');
      }
    } catch (error) {
      console.error(`Failed to delete report ${reportId}:`, error);
      alert(`Failed to delete report ${reportId}`);
    }
  };

  if (loading) {
    return <div className="container"><p>Loading reports...</p></div>;
  }

  return (
    <div className="container">
      <div className="subpage-nav">
        <ul>
          <li><a href="/reports" className={reportId ? '' : 'active'}>All Reports</a></li>
          {selectedReport && (
            <li><a href={`/reports/${selectedReport.id}`} className={reportId ? 'active' : ''}>Report #{selectedReport.id}</a></li>
          )}
        </ul>
      </div>

      <h2 className="page-title">Test Reports</h2>

      <div className="card">
        <h3>Reports List</h3>
        <div className="report-list-container">
          <ReportList 
            reports={reports} 
            onSelectReport={(testReport) => {
              setSelectedReport(testReport);
              navigate(`/reports/${testReport.id}`);
            }}
            onDeleteReport={handleDeleteReport}
          />
        </div>
      </div>

      <Routes>
        <Route 
          path="/:reportId" 
          element={
            <ReportDetail 
              testReport={selectedReport} 
              onDeleteReport={handleDeleteReport}
            />
          } 
        />
      </Routes>
    </div>
  );
};

export default ReportsPage;