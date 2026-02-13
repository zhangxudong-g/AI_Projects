import React from 'react';
import { TestReport } from '../types';
import Modal from './Modal';
import ReportResultTable from './ReportResultTable';

interface ReportDetailProps {
  testReport: TestReport | null;
  onDeleteReport: (reportId: number) => void;
  isOpen?: boolean; // 是否以弹窗形式打开
  onClose?: () => void; // 关闭弹窗的回调函数
}

const ReportDetail: React.FC<ReportDetailProps> = ({ testReport, onDeleteReport, isOpen = false, onClose }) => {
  if (!testReport) {
    return <div className="container"><p>Select a report to view details</p></div>;
  }

  const reportDetailContent = (
    <div className="report-detail-content">
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
            <ReportResultTable testReport={testReport} />
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
  );

  // 如果需要以弹窗形式显示
  if (isOpen && onClose) {
    return (
      <Modal
        isOpen={isOpen}
        onClose={onClose}
        title={`Report Details: ${testReport.report_name}`}
      >
        {reportDetailContent}
      </Modal>
    );
  }

  // 否则以普通组件形式显示
  return (
    <div className="container">
      <div className="card">
        <h3>Report Details: {testReport.report_name}</h3>
        {reportDetailContent}
      </div>
    </div>
  );
};


export default ReportDetail;