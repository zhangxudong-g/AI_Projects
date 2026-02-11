import React from 'react';
import { TestReport } from '../types';

interface ReportDetailProps {
  testReport: TestReport | null;
  onDeleteReport: (reportId: number) => void;
}

const ReportDetail: React.FC<ReportDetailProps> = ({ testReport, onDeleteReport }) => {
  if (!testReport) {
    return <div className="container"><p>Select a report to view details</p></div>;
  }

  return (
    <div className="container">
      <div className="card">
        <h3>Report Details: {testReport.report_name}</h3>
        
        <div className="report-info">
          <p><strong>ID:</strong> {testReport.id}</p>
          <p><strong>Name:</strong> {testReport.report_name}</p>
          <p><strong>Status:</strong> 
            <span className={`status-badge status-${testReport.status.toLowerCase()}`} style={{ marginLeft: '8px' }}>
              {testReport.status}
            </span>
          </p>
          <p><strong>Final Score:</strong> {testReport.final_score != null ? testReport.final_score.toFixed(2) : 'N/A'}</p>
          <p><strong>Plan ID:</strong> {testReport.plan_id || 'N/A'}</p>
          <p><strong>Case ID:</strong> {testReport.case_id || 'N/A'}</p>
          <p><strong>Created:</strong> {new Date(testReport.created_at).toLocaleString()}</p>
          
          {testReport.result && (
            <div className="result-section">
              <h4>Result Details:</h4>
              <pre className="result-json">
                {(() => {
                  try {
                    const parsedResult = JSON.parse(testReport.result);
                    return JSON.stringify(parsedResult, null, 2);
                  } catch (e) {
                    // 如果解析失败，直接显示原始字符串
                    return testReport.result;
                  }
                })()}
              </pre>
            </div>
          )}
          
          {testReport.output_path && (
            <p><strong>Output Path:</strong> {testReport.output_path}</p>
          )}
        </div>
        
        <div className="actions">
          <button 
            className="btn btn-danger"
            onClick={() => onDeleteReport(testReport.id)}
          >
            Delete Report
          </button>
        </div>
      </div>
    </div>
  );
};

export default ReportDetail;