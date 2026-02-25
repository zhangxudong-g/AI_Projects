import React, { useState } from 'react';
import { TestReport } from '../types';
import { reportApi } from '../api';

interface ReportListProps {
  reports: TestReport[];
  onSelectReport: (testReport: TestReport) => void;
  onDeleteReport: (reportId: number) => void;
  onBulkDelete: (reportIds: number[]) => void;
}

const ReportList: React.FC<ReportListProps> = ({ reports, onSelectReport, onDeleteReport, onBulkDelete }) => {
  const [selectedReports, setSelectedReports] = useState<number[]>([]);
  const [deleting, setDeleting] = useState(false);
  const [exporting, setExporting] = useState<number | null>(null); // 正在导出的报告 ID

  if (reports.length === 0) {
    return <p>No test reports found.</p>;
  }

  // 下载报告文件
  const handleDownload = async (
    exportFunc: (id: number) => Promise<any>,
    filename: string,
    reportId: number
  ) => {
    setExporting(reportId);
    try {
      const response = await exportFunc(reportId);
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
    } finally {
      setExporting(null);
    }
  };

  const handleSelectAll = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.checked) {
      setSelectedReports(reports.map(report => report.id));
    } else {
      setSelectedReports([]);
    }
  };

  const handleSingleSelect = (id: number, checked: boolean) => {
    if (checked) {
      setSelectedReports(prev => [...prev, id]);
    } else {
      setSelectedReports(prev => prev.filter(reportId => reportId !== id));
    }
  };

  const handleBulkDelete = () => {
    if (selectedReports.length > 0) {
      const reportNames = selectedReports.slice(0, 5).map(id =>
        reports.find(r => r.id === id)?.report_name || `Report ${id}`
      ).join(', ');
      const extraCount = selectedReports.length - 5;

      let confirmationMessage = `Are you sure you want to delete ${selectedReports.length} report(s)?`;
      if (selectedReports.length > 5) {
        confirmationMessage += `\n\nSelected reports: ${reportNames} and ${extraCount} more.`;
      } else {
        confirmationMessage += `\n\nSelected reports: ${reportNames}`;
      }

      if (window.confirm(confirmationMessage)) {
        setDeleting(true);
        onBulkDelete(selectedReports);
      }
    } else {
      alert('Please select at least one report to delete.');
    }
  };

  return (
    <div className="report-list">
      <div className="table-header">
        <div className="bulk-actions">
          <button
            className="btn btn-danger"
            onClick={handleBulkDelete}
            disabled={selectedReports.length === 0 || deleting}
          >
            {deleting ? 'Deleting...' : `Bulk Delete (${selectedReports.length})`}
          </button>
        </div>
      </div>

      <table className="table">
        <thead>
          <tr>
            <th className="col-checkbox">
              <input
                type="checkbox"
                onChange={handleSelectAll}
                checked={selectedReports.length === reports.length && reports.length > 0}
              />
            </th>
            <th className="col-id">ID</th>
            <th className="col-name">Name</th>
            <th className="col-score">Score</th>
            <th className="col-created">Created At</th>
            <th className="col-export">Export</th>
            <th className="col-actions">Actions</th>
          </tr>
        </thead>
        <tbody>
          {reports.map((testReport) => (
            <tr key={testReport.id}>
              <td>
                <input
                  type="checkbox"
                  checked={selectedReports.includes(testReport.id)}
                  onChange={(e) => handleSingleSelect(testReport.id, e.target.checked)}
                />
              </td>
              <td>{testReport.id}</td>
              <td title={testReport.report_name}>{testReport.report_name}</td>
              <td>{testReport.final_score != null ? testReport.final_score.toFixed(2) : '-'}</td>
              <td>{new Date(testReport.created_at).toLocaleString()}</td>
              <td>
                <div className="export-buttons" style={{ display: 'flex', gap: '4px' }}>
                  <button
                    className="btn btn-sm btn-secondary"
                    onClick={() => handleDownload(
                      reportApi.exportReportJson,
                      `report_${testReport.id}.json`,
                      testReport.id
                    )}
                    disabled={exporting === testReport.id}
                    title="Export as JSON"
                  >
                    {exporting === testReport.id ? '⏳' : '📄'}
                  </button>
                  <button
                    className="btn btn-sm btn-secondary"
                    onClick={() => handleDownload(
                      reportApi.exportReportMarkdown,
                      `report_${testReport.id}.md`,
                      testReport.id
                    )}
                    disabled={exporting === testReport.id}
                    title="Export as Markdown"
                  >
                    {exporting === testReport.id ? '⏳' : '📝'}
                  </button>
                  <button
                    className="btn btn-sm btn-secondary"
                    onClick={() => handleDownload(
                      reportApi.exportReportCsv,
                      `report_${testReport.id}.csv`,
                      testReport.id
                    )}
                    disabled={exporting === testReport.id}
                    title="Export as CSV"
                  >
                    {exporting === testReport.id ? '⏳' : '📊'}
                  </button>
                </div>
              </td>
              <td>
                <div className="action-buttons">
                  <button
                    className="btn btn-sm"
                    onClick={() => onSelectReport(testReport)}
                    title="View Report"
                  >
                    View
                  </button>
                  <button
                    className="btn btn-danger btn-sm"
                    onClick={() => onDeleteReport(testReport.id)}
                    title="Delete Report"
                  >
                    Del
                  </button>
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default ReportList;
