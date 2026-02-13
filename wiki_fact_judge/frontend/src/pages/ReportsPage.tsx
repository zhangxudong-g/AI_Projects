import React, { useState, useEffect } from 'react';
import { reportApi } from '../api';
import { TestReport } from '../types';
import ReportList from '../components/ReportList';
import ReportDetail from '../components/ReportDetail';
import { useParams, useNavigate } from 'react-router-dom';

const ReportsPage: React.FC = () => {
  const [reports, setReports] = useState<TestReport[]>([]);
  const [selectedReport, setSelectedReport] = useState<TestReport | null>(null);
  const [loading, setLoading] = useState(true);
  const [showReportModal, setShowReportModal] = useState(false); // 控制报告详情弹窗
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
      setShowReportModal(true); // 显示弹窗
    } else {
      setSelectedReport(null);
      setShowReportModal(false); // 隐藏弹窗
    }
  }, [reportId, reports]); // 这个依赖于reports数组，当reports更新时会重新执行

  const fetchReports = async () => {
    try {
      setLoading(true);
      const response = await reportApi.getAllReports("created_at_desc"); // 按最新创建时间排序
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

  const handleBulkDeleteReports = async (reportIds: number[]) => {
    try {
      const response = await reportApi.bulkDeleteReports(reportIds);
      const deletedCount = response.data.length;
      alert(`${deletedCount} report(s) deleted successfully`);
      // 刷新报告列表
      fetchReports();
      // 如果已选中的报告被删除，则清除选择
      if (selectedReport && reportIds.includes(selectedReport.id)) {
        setSelectedReport(null);
        navigate('/reports');
      }
    } catch (error: any) {
      console.error(`Failed to bulk delete reports:`, error);
      let errorMessage = 'Failed to bulk delete reports';
      if (error.response?.data?.detail) {
        errorMessage = error.response.data.detail;
      } else if (error.message) {
        errorMessage = error.message;
      }
      alert(errorMessage);
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
              setShowReportModal(true); // 显示弹窗而不是导航
            }}
            onDeleteReport={handleDeleteReport}
            onBulkDelete={handleBulkDeleteReports}
          />
        </div>
      </div>

      {/* 报告详情弹窗 */}
      <ReportDetail
        testReport={selectedReport}
        onDeleteReport={handleDeleteReport}
        isOpen={showReportModal}
        onClose={() => {
          setShowReportModal(false);
          setSelectedReport(null);
          navigate('/reports'); // 返回到报告列表页
        }}
      />
    </div>
  );
};

export default ReportsPage;