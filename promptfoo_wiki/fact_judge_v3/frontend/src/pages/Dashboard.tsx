import React, { useState, useEffect } from 'react';
import { Card, Row, Col, Statistic, Table, Typography, Button, message } from 'antd';
import { ArrowUpOutlined, ArrowDownOutlined, PlayCircleOutlined, UploadOutlined, FileTextOutlined } from '@ant-design/icons';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import apiClient from '../utils/api';

const { Title } = Typography;

// 定义类型
interface DashboardStats {
  totalExecutions: number;
  successRate: number;
  averageScore: number;
  recentFailures: number;
}

interface TrendData {
  date: string;
  executions: number;
  avgScore: number;
}

interface ActivityItem {
  id: string;
  case: string;
  status: string;
  score: number | string;
  date: string;
}

const DashboardPage: React.FC = () => {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [trendData, setTrendData] = useState<TrendData[]>([]);
  const [recentActivity, setRecentActivity] = useState<ActivityItem[]>([]);
  const [loading, setLoading] = useState(true);

  // 获取仪表盘数据
  useEffect(() => {
    fetchDashboardData();
  }, []);

  const fetchDashboardData = async () => {
    try {
      // 获取统计信息
      const statsResponse = await apiClient.get('/dashboard/stats');
      setStats(statsResponse.data);

      // 获取趋势数据
      const trendsResponse = await apiClient.get('/dashboard/trends');
      setTrendData(trendsResponse.data);

      // 获取最近活动
      const activityResponse = await apiClient.get('/dashboard/recent');
      setRecentActivity(activityResponse.data);
    } catch (error) {
      console.error('Failed to fetch dashboard data:', error);
      message.error('Failed to load dashboard data');

      // 如果API调用失败，使用模拟数据作为后备
      setStats({
        totalExecutions: 128,
        successRate: 85.3,
        averageScore: 72.4,
        recentFailures: 8
      });

      setTrendData([
        { date: 'Mon', executions: 42, avgScore: 75 },
        { date: 'Tue', executions: 38, avgScore: 78 },
        { date: 'Wed', executions: 56, avgScore: 70 },
        { date: 'Thu', executions: 49, avgScore: 82 },
        { date: 'Fri', executions: 63, avgScore: 76 },
        { date: 'Sat', executions: 35, avgScore: 69 },
        { date: 'Sun', executions: 41, avgScore: 74 }
      ]);

      setRecentActivity([
        { id: 'exec-001', case: 'Java Controller Eval', status: 'Completed', score: 82, date: '2026-02-10 10:30' },
        { id: 'exec-002', case: 'SQL Procedure Eval', status: 'Failed', score: 35, date: '2026-02-10 09:45' },
        { id: 'exec-003', case: 'Python Module Eval', status: 'Completed', score: 91, date: '2026-02-10 08:20' },
        { id: 'exec-004', case: 'JS Component Eval', status: 'Running', score: '-', date: '2026-02-10 07:15' },
      ]);
    } finally {
      setLoading(false);
    }
  };

  // 将统计数据显示为数组格式
  const statsData = stats ? [
    { title: 'Total Executions', value: stats.totalExecutions, trend: 'up' as const, percentage: 12.5 },
    { title: 'Success Rate', value: stats.successRate, suffix: '%', trend: 'up' as const, percentage: 3.2 },
    { title: 'Avg. Score', value: stats.averageScore, trend: stats.averageScore > 70 ? ('up' as const) : ('down' as const), percentage: 1.8 },
    { title: 'Recent Failures', value: stats.recentFailures, trend: 'down' as const, percentage: 2.1 }
  ] : [];

  // 模拟操作函数
  const handleRunEvaluation = () => {
    message.info('Running new evaluation...');
    // 这里应该调用实际的API
  };

  const handleUploadCase = () => {
    message.info('Uploading new case...');
    // 这里应该调用实际的API
  };

  const handleViewReports = () => {
    message.info('Redirecting to reports...');
    // 这里应该导航到报告页面
  };

  return (
    <div>
      <Title level={2}>Dashboard</Title>

      {/* 统计卡片 */}
      <Row gutter={16} style={{ marginBottom: 24 }}>
        {statsData.map((stat, index) => (
          <Col span={6} key={index}>
            <Card>
              <Statistic
                title={stat.title}
                value={stat.value}
                precision={stat.suffix ? 1 : 0}
                valueStyle={{ color: stat.trend === 'up' ? '#3f8600' : '#cf1322' }}
                prefix={stat.trend === 'up' ? <ArrowUpOutlined /> : <ArrowDownOutlined />}
                suffix={stat.suffix}
                formatter={(value) => (
                  <div>
                    {value}
                    <div style={{ fontSize: '12px', color: '#8c8c8c', marginTop: 4 }}>
                      {stat.trend === 'up' ? '+' : '-'}{stat.percentage}% from last week
                    </div>
                  </div>
                )}
              />
            </Card>
          </Col>
        ))}
      </Row>

      {/* 图表区域 */}
      <Row gutter={16} style={{ marginBottom: 24 }}>
        <Col span={16}>
          <Card title="Weekly Activity">
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={trendData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="date" />
                <YAxis yAxisId="left" orientation="left" stroke="#1890ff" />
                <YAxis yAxisId="right" orientation="right" stroke="#52c41a" />
                <Tooltip />
                <Legend />
                <Bar yAxisId="left" dataKey="executions" fill="#1890ff" name="Executions" />
                <Bar yAxisId="right" dataKey="avgScore" fill="#52c41a" name="Avg. Score" />
              </BarChart>
            </ResponsiveContainer>
          </Card>
        </Col>
        <Col span={8}>
          <Card title="Quick Actions">
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              <Button 
                icon={<PlayCircleOutlined />} 
                onClick={handleRunEvaluation}
                style={{ justifyContent: 'flex-start' }}
              >
                Run New Evaluation
              </Button>
              <Button 
                icon={<UploadOutlined />} 
                onClick={handleUploadCase}
                style={{ justifyContent: 'flex-start' }}
              >
                Upload New Case
              </Button>
              <Button 
                icon={<FileTextOutlined />} 
                onClick={handleViewReports}
                style={{ justifyContent: 'flex-start' }}
              >
                View Reports
              </Button>
            </div>
          </Card>
        </Col>
      </Row>

      {/* 最近活动 */}
      <Row>
        <Col span={24}>
          <Card title="Recent Activity">
            <Table
              dataSource={recentActivity}
              columns={[
                { title: 'ID', dataIndex: 'id', key: 'id' },
                { title: 'Case Name', dataIndex: 'case', key: 'case' },
                { title: 'Status', dataIndex: 'status', key: 'status' },
                { title: 'Score', dataIndex: 'score', key: 'score' },
                { title: 'Date', dataIndex: 'date', key: 'date' },
              ]}
              rowKey="id"
              loading={loading}
              pagination={{ pageSize: 5 }}
            />
          </Card>
        </Col>
      </Row>
    </div>
  );
};

export default DashboardPage;