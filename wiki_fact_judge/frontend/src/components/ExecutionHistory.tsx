import React, { useState, useEffect, useCallback } from 'react';
import { TestReport } from '../types';
import ExecutionHistoryChart from './ExecutionHistoryChart';
import GenericTable from './GenericTable';
import { reportApi } from '../api';

interface ExecutionHistoryProps {
  planId: number;
  title?: string;
}

interface ExecutionRecord {
  id: number;
  timestamp: string;
  score: number;
  status: string;
  reportId: number;
}

const ExecutionHistory: React.FC<ExecutionHistoryProps> = ({ planId, title = "Execution History" }) => {
  const [records, setRecords] = useState<ExecutionRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchExecutionHistory = useCallback(async () => {
    try {
      setLoading(true);
      // 获取与该计划相关的所有报告
      const response = await reportApi.getAllReports("created_at_asc"); // 按时间升序排列
      const allReports: TestReport[] = response.data;
      const planReports = allReports.filter((report: TestReport) => report.plan_id === planId);
      
      // 转换为执行记录
      const executionRecords: ExecutionRecord[] = planReports.map(report => ({
        id: report.id,
        timestamp: report.created_at,
        score: report.final_score || 0,
        status: report.status,
        reportId: report.id
      }));

      setRecords(executionRecords);
    } catch (err) {
      console.error('Failed to fetch execution history:', err);
      setError('Failed to fetch execution history');
    } finally {
      setLoading(false);
    }
  }, [planId]);

  useEffect(() => {
    fetchExecutionHistory();
  }, [fetchExecutionHistory]);

  if (loading) {
    return <div className="execution-history">Loading execution history...</div>;
  }

  if (error) {
    return <div className="execution-history error">{error}</div>;
  }

  if (records.length === 0) {
    return (
      <div className="execution-history">
        <h4>{title}</h4>
        <p>No execution history found for this plan.</p>
      </div>
    );
  }

  // 准备图表数据
  const chartData = records.map(record => ({
    id: record.id,
    timestamp: record.timestamp,
    score: record.score,
    status: record.status
  }));

  // 准备汇总数据
  const summaryData = {
    'Total Executions': records.length,
    'Latest Score': records[records.length - 1].score,
    'Average Score': (records.reduce((sum, record) => sum + record.score, 0) / records.length).toFixed(2),
    'Best Score': Math.max(...records.map(r => r.score)),
    'Worst Score': Math.min(...records.map(r => r.score)),
    'Success Rate': `${((records.filter(r => r.status === 'FINISHED').length / records.length) * 100).toFixed(2)}%`
  };

  return (
    <div className="execution-history">
      <h4>{title}</h4>
      <GenericTable data={summaryData} title="Execution Summary" />
      <ExecutionHistoryChart records={chartData} />
      
      <div className="execution-details">
        <h5>Execution Details</h5>
        <table className="table">
          <thead>
            <tr>
              <th>Date</th>
              <th>Score</th>
              <th>Status</th>
              <th>Report ID</th>
            </tr>
          </thead>
          <tbody>
            {records.map(record => (
              <tr key={record.id}>
                <td>{new Date(record.timestamp).toLocaleString()}</td>
                <td>{record.score}</td>
                <td>
                  <span className={`status-badge status-${record.status.toLowerCase()}`}>
                    {record.status}
                  </span>
                </td>
                <td>{record.reportId}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default ExecutionHistory;