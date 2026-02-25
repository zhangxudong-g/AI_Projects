import React from 'react';
import { TestReport } from '../types';
import Modal from './Modal';
import ReportResultTable from './ReportResultTable';
import { reportApi } from '../api';

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

  // 下载报告文件
  const handleDownload = async (exportFunc: (id: number) => Promise<any>, filename: string) => {
    try {
      const response = await exportFunc(testReport.id);
      const blob = new Blob([response.data], { type: response.headers['content-type'] });
      const url = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = filename;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(url);
    } catch (error) {
      console.error('Failed to export report:', error);
      alert('Failed to export report. Please try again.');
    }
  };

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
        
        {/* Final Score - 根据状态智能显示 */}
        {testReport.final_score != null ? (
          <p><strong>Final Score:</strong> {testReport.final_score.toFixed(2)}</p>
        ) : testReport.status === 'RUNNING' || testReport.status === 'PENDING' ? (
          <p><strong>Final Score:</strong> <span style={{ color: '#999' }}>待计算</span></p>
        ) : null}
        
        {/* Plan ID - 可选字段，为空时隐藏 */}
        {testReport.plan_id != null && (
          <p><strong>Plan ID:</strong> {testReport.plan_id}</p>
        )}
        
        {/* Case ID - 可选字段，为空时隐藏 */}
        {testReport.case_id != null && (
          <p><strong>Case ID:</strong> {testReport.case_id}</p>
        )}
        
        <p><strong>Created:</strong> {new Date(testReport.created_at).toLocaleString()}</p>

        {testReport.result && (
          <div className="result-section">
            <h4>Result Details:</h4>
            <ReportResultTable testReport={testReport} />
          </div>
        )}

        {/* Output Path - 可选字段，为空时隐藏 */}
        {testReport.output_path && (
          <p><strong>Output Path:</strong> {testReport.output_path}</p>
        )}
      </div>

      {/* 导出按钮组 */}
      <div className="export-buttons" style={{ marginTop: '20px', marginBottom: '20px' }}>
        <h4 style={{ marginBottom: '10px' }}>Export Report:</h4>
        <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
          <button
            className="btn btn-secondary"
            onClick={() => handleDownload(
              reportApi.exportReportJson,
              `report_${testReport.id}.json`
            )}
            title="Export as JSON"
          >
            📄 JSON
          </button>
          <button
            className="btn btn-secondary"
            onClick={() => handleDownload(
              reportApi.exportReportMarkdown,
              `report_${testReport.id}.md`
            )}
            title="Export as Markdown"
          >
            📝 Markdown
          </button>
          <button
            className="btn btn-secondary"
            onClick={() => handleDownload(
              reportApi.exportReportCsv,
              `report_${testReport.id}.csv`
            )}
            title="Export as CSV"
          >
            📊 CSV
          </button>
          {testReport.plan_id && (
            <>
              <button
                className="btn btn-secondary"
                onClick={() => handleDownload(
                  reportApi.exportPlanReportsJson,
                  `plan_${testReport.plan_id}_reports.json`
                )}
                title="Export entire Plan as JSON"
              >
                📁 Plan JSON
              </button>
              <button
                className="btn btn-secondary"
                onClick={() => handleDownload(
                  reportApi.exportPlanReportsMarkdown,
                  `plan_${testReport.plan_id}_reports.md`
                )}
                title="Export entire Plan as Markdown"
              >
                📁 Plan Markdown
              </button>
              <button
                className="btn btn-secondary"
                onClick={() => handleDownload(
                  reportApi.exportPlanReportsCsv,
                  `plan_${testReport.plan_id}_reports.csv`
                )}
                title="Export entire Plan as CSV"
              >
                📁 Plan CSV
              </button>
            </>
          )}
        </div>
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
