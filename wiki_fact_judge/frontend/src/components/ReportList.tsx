import React from 'react';
import { TestReport } from '../types';

interface ReportListProps {
  reports: TestReport[];
  onSelectReport: (testReport: TestReport) => void;
  onDeleteReport: (reportId: number) => void;
}

const ReportList: React.FC<ReportListProps> = ({ reports, onSelectReport, onDeleteReport }) => {
  if (reports.length === 0) {
    return <p>No test reports found.</p>;
  }

  return (
    <div className="report-list">
      <table className="table">
        <thead>
          <tr>
            <th>ID</th>
            <th>Name</th>
            <th>Status</th>
            <th>Score</th>
            <th>Created At</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {reports.map((testReport) => (
            <tr key={testReport.id}>
              <td>{testReport.id}</td>
              <td>{testReport.report_name}</td>
              <td>
                <span className={`status-badge status-${testReport.status.toLowerCase()}`}>
                  {testReport.status}
                </span>
              </td>
              <td>{testReport.final_score != null ? testReport.final_score.toFixed(2) : '-'}</td>
              <td>{new Date(testReport.created_at).toLocaleString()}</td>
              <td>
                <button 
                  className="btn"
                  onClick={() => onSelectReport(testReport)}
                >
                  View
                </button>
                <button 
                  className="btn btn-danger"
                  onClick={() => onDeleteReport(testReport.id)}
                >
                  Delete
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default ReportList;