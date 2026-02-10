import React from 'react';
import { Card, Row, Col, Statistic, Table, Typography } from 'antd';
import { ArrowUpOutlined, ArrowDownOutlined } from '@ant-design/icons';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';

const { Title } = Typography;

// 模拟数据
const statsData = [
  { title: 'Total Executions', value: 128, trend: 'up', percentage: 12.5 },
  { title: 'Success Rate', value: 85.3, suffix: '%', trend: 'up', percentage: 3.2 },
  { title: 'Avg. Score', value: 72.4, trend: 'down', percentage: 1.8 },
  { title: 'Recent Failures', value: 8, trend: 'down', percentage: 2.1 }
];

const chartData = [
  { name: 'Mon', executions: 42, avgScore: 75 },
  { name: 'Tue', executions: 38, avgScore: 78 },
  { name: 'Wed', executions: 56, avgScore: 70 },
  { name: 'Thu', executions: 49, avgScore: 82 },
  { name: 'Fri', executions: 63, avgScore: 76 },
  { name: 'Sat', executions: 35, avgScore: 69 },
  { name: 'Sun', executions: 41, avgScore: 74 }
];

const recentActivityData = [
  { id: 'exec-001', case: 'Java Controller Eval', status: 'Completed', score: 82, date: '2026-02-10 10:30' },
  { id: 'exec-002', case: 'SQL Procedure Eval', status: 'Failed', score: 35, date: '2026-02-10 09:45' },
  { id: 'exec-003', case: 'Python Module Eval', status: 'Completed', score: 91, date: '2026-02-10 08:20' },
  { id: 'exec-004', case: 'JS Component Eval', status: 'Running', score: '-', date: '2026-02-10 07:15' },
];

const DashboardPage: React.FC = () => {
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
              <BarChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="name" />
                <YAxis />
                <Tooltip />
                <Legend />
                <Bar dataKey="executions" fill="#1890ff" name="Executions" />
                <Bar dataKey="avgScore" fill="#52c41a" name="Avg. Score" />
              </BarChart>
            </ResponsiveContainer>
          </Card>
        </Col>
        <Col span={8}>
          <Card title="Quick Actions">
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              <button style={{ padding: '12px', border: '1px solid #d9d9d9', borderRadius: '4px', cursor: 'pointer' }}>
                Run New Evaluation
              </button>
              <button style={{ padding: '12px', border: '1px solid #d9d9d9', borderRadius: '4px', cursor: 'pointer' }}>
                Upload New Case
              </button>
              <button style={{ padding: '12px', border: '1px solid #d9d9d9', borderRadius: '4px', cursor: 'pointer' }}>
                View Reports
              </button>
            </div>
          </Card>
        </Col>
      </Row>

      {/* 最近活动 */}
      <Row>
        <Col span={24}>
          <Card title="Recent Activity">
            <Table 
              dataSource={recentActivityData} 
              columns={[
                { title: 'ID', dataIndex: 'id', key: 'id' },
                { title: 'Case Name', dataIndex: 'case', key: 'case' },
                { title: 'Status', dataIndex: 'status', key: 'status' },
                { title: 'Score', dataIndex: 'score', key: 'score' },
                { title: 'Date', dataIndex: 'date', key: 'date' },
              ]}
              rowKey="id"
              pagination={{ pageSize: 5 }}
            />
          </Card>
        </Col>
      </Row>
    </div>
  );
};

export default DashboardPage;