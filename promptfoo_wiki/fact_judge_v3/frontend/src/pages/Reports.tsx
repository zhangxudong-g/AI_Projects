import React, { useState, useEffect } from 'react';
import { 
  Table, 
  Button, 
  Modal, 
  Form, 
  Input, 
  Select, 
  Space, 
  Tag,
  Typography,
  message,
  Card,
  Row,
  Col,
  Statistic
} from 'antd';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';
import { PlusOutlined, DownOutlined } from '@ant-design/icons';
import { Dropdown } from 'antd';
import apiClient from '../utils/api';

const { Title } = Typography;
const { Option } = Select;

// 定义 Report 类型
interface ReportItem {
  id: string;
  execution_id: string;
  case_id: string;
  case_name?: string;
  final_score: number;
  result: string;
  details: any;
  created_at: string;
}

const ReportsPage: React.FC = () => {
  const [reports, setReports] = useState<ReportItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [modalVisible, setModalVisible] = useState(false);
  const [editingReport, setEditingReport] = useState<ReportItem | null>(null);
  const [chartData, setChartData] = useState<any[]>([]);
  const [scoreDistribution, setScoreDistribution] = useState<any>({});
  const [successRate, setSuccessRate] = useState<number>(0);
  const [totalReports, setTotalReports] = useState<number>(0);
  const [filters, setFilters] = useState<{ status?: string; dateRange?: [string, string]; minScore?: number; maxScore?: number }>({});
  const [sortInfo, setSortInfo] = useState<{ field: string; order: 'ascend' | 'descend' } | null>(null);
  const [form] = Form.useForm();

  // 获取报告列表
  useEffect(() => {
    fetchReports();
    fetchChartData();
  }, []);

  const fetchReports = async () => {
    setLoading(true);
    try {
      const response = await apiClient.get('/reports');
      setReports(response.data);
    } catch (error) {
      console.error('Failed to fetch reports:', error);
      message.error('Failed to fetch reports');
      
      // 如果API调用失败，使用模拟数据作为后备
      setReports([
        { id: 'rep-001', execution_id: 'exec-001', case_id: 'case-001', case_name: 'Java Controller Eval', final_score: 82, result: 'PASS', details: { summary: 'Good documentation' }, created_at: '2026-02-10T09:45:00' },
        { id: 'rep-002', execution_id: 'exec-002', case_id: 'case-002', case_name: 'SQL Procedure Eval', final_score: 35, result: 'FAIL', details: { summary: 'Missing details' }, created_at: '2026-02-10T10:15:00' },
        { id: 'rep-003', execution_id: 'exec-003', case_id: 'case-003', case_name: 'Python Module Eval', final_score: 91, result: 'PASS', details: { summary: 'Excellent documentation' }, created_at: '2026-02-10T08:50:00' },
        { id: 'rep-004', execution_id: 'exec-004', case_id: 'case-001', case_name: 'Java Controller Eval', final_score: 42, result: 'FAIL', details: { summary: 'Low quality' }, created_at: '2026-02-10T07:45:00' },
      ]);
    } finally {
      setLoading(false);
    }
  };

  const fetchChartData = async () => {
    try {
      const response = await apiClient.get('/reports/charts');
      const data = response.data;
      
      setScoreDistribution(data.scoreDistribution || {});
      setSuccessRate(data.successRate || 0);
      setTotalReports(data.totalReports || 0);

      // 准备柱状图数据
      const barData = Object.entries(data.scoreDistribution || {}).map(([range, count]) => ({
        name: range,
        count: count as number
      }));

      setChartData(barData);
    } catch (error) {
      console.error('Failed to fetch chart data:', error);
      
      // 如果API调用失败，使用模拟数据作为后备
      const distribution = {
        "30-40": 2,
        "40-50": 1,
        "70-80": 1,
        "90-100": 1
      };

      setScoreDistribution(distribution);
      setSuccessRate(60); // 60% 成功率
      setTotalReports(5); // 总共5个报告

      // 准备柱状图数据
      const barData = Object.entries(distribution).map(([range, count]) => ({
        name: range,
        count: count as number
      }));

      setChartData(barData);
    }
  };

  const handleAddReport = () => {
    setEditingReport(null);
    form.resetFields();
    setModalVisible(true);
  };

  const handleEditReport = (record: ReportItem) => {
    setEditingReport(record);
    form.setFieldsValue(record);
    setModalVisible(true);
  };

  const handleDeleteReport = async (id: string) => {
    try {
      await apiClient.delete(`/reports/${id}`);
      message.success('Report deleted successfully');
      fetchReports(); // 重新获取列表
    } catch (error) {
      console.error('Failed to delete report:', error);
      message.error('Failed to delete report');
    }
  };

  const handleSaveReport = async () => {
    try {
      const values = await form.validateFields();

      if (editingReport) {
        // 更新现有报告
        await apiClient.put(`/reports/${editingReport.id}`, values);
      } else {
        // 创建新报告
        await apiClient.post('/reports', values);
      }

      message.success(`Report ${editingReport ? 'updated' : 'created'} successfully`);
      setModalVisible(false);
      fetchReports(); // 重新获取列表
    } catch (error) {
      console.error('Failed to save report:', error);
      message.error('Failed to save report');
    }
  };

  const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884D8'];

  const columns = [
    {
      title: 'ID',
      dataIndex: 'id',
      key: 'id',
      filteredValue: filters.id || null,
      onFilter: (value: string, record: ReportItem) => record.id.includes(value),
    },
    {
      title: 'Case Name',
      dataIndex: 'case_name',
      key: 'case_name',
      filteredValue: filters.case_name || null,
      onFilter: (value: string, record: ReportItem) => record.case_name?.includes(value) || false,
    },
    {
      title: 'Final Score',
      dataIndex: 'final_score',
      key: 'final_score',
      sorter: (a: ReportItem, b: ReportItem) => a.final_score - b.final_score,
      sortOrder: sortInfo?.field === 'final_score' ? sortInfo.order : null,
      filteredValue: filters.score_range || null,
      render: (score: number) => (
        <span style={{ fontWeight: 'bold', color: score >= 70 ? '#52c41a' : score >= 50 ? '#faad14' : '#ff4d4f' }}>
          {score}
        </span>
      ),
    },
    {
      title: 'Result',
      dataIndex: 'result',
      key: 'result',
      filters: [
        { text: 'PASS', value: 'PASS' },
        { text: 'FAIL', value: 'FAIL' },
      ],
      filteredValue: filters.result || null,
      onFilter: (value: string, record: ReportItem) => record.result === value,
      render: (result: string) => (
        <Tag color={result === 'PASS' ? 'green' : 'red'}>
          {result}
        </Tag>
      ),
    },
    {
      title: 'Created At',
      dataIndex: 'created_at',
      key: 'created_at',
      sorter: (a: ReportItem, b: ReportItem) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime(),
      sortOrder: sortInfo?.field === 'created_at' ? sortInfo.order : null,
      render: (time: string) => new Date(time).toLocaleString(),
    },
    {
      title: 'Actions',
      key: 'actions',
      render: (_: any, record: ReportItem) => (
        <Space>
          <Dropdown
            menu={{
              items: [
                {
                  key: 'view',
                  label: 'View',
                  onClick: () => handleEditReport(record)
                },
                {
                  key: 'export-json',
                  label: 'Export as JSON',
                  onClick: () => handleExportReport(record.id, 'json')
                },
                {
                  key: 'export-csv',
                  label: 'Export as CSV',
                  onClick: () => handleExportReport(record.id, 'csv')
                },
                {
                  type: 'divider',
                },
                {
                  key: 'delete',
                  label: 'Delete',
                  danger: true,
                  onClick: () => handleDeleteReport(record.id)
                }
              ]
            }}
          >
            <Button>
              <Space>
                Actions
                <DownOutlined />
              </Space>
            </Button>
          </Dropdown>
        </Space>
      ),
    },
  ];

  const handleExportReport = async (reportId: string, format: 'json' | 'csv') => {
    try {
      // 实现报告导出逻辑
      const response = await apiClient.get(`/reports/export/${reportId}?format=${format}`, {
        responseType: 'blob' // 用于处理文件下载
      });
      
      // 创建下载链接
      const url = window.URL.createObjectURL(new Blob([response.data]));
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', `report_${reportId}.${format}`);
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(url);
    } catch (error) {
      console.error('Failed to export report:', error);
      message.error(`Failed to export report as ${format.toUpperCase()}`);
    }
  };

  const handleBatchExport = async (format: 'json' | 'csv') => {
    try {
      // 实现批量导出逻辑
      const response = await apiClient.get(`/reports/export/batch?format=${format}`, {
        responseType: 'blob' // 用于处理文件下载
      });
      
      // 创建下载链接
      const url = window.URL.createObjectURL(new Blob([response.data]));
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', `reports_batch.${format}`);
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(url);
    } catch (error) {
      console.error('Failed to batch export reports:', error);
      message.error(`Failed to export reports as ${format.toUpperCase()}`);
    }
  };

  const handleTableChange = (pagination: any, filters: any, sorter: any) => {
    // 处理过滤和排序变化
    setFilters(filters);
    setSortInfo(sorter.order ? { field: sorter.field, order: sorter.order } : null);
  };

  return (
    <div>
      <div style={{ marginBottom: 16, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Title level={2}>Reports</Title>
        <Space>
          <Dropdown
            menu={{
              items: [
                {
                  key: 'batch-export-json',
                  label: 'Export All as JSON',
                  onClick: () => handleBatchExport('json')
                },
                {
                  key: 'batch-export-csv',
                  label: 'Export All as CSV',
                  onClick: () => handleBatchExport('csv')
                }
              ]
            }}
          >
            <Button>
              <Space>
                Export Reports
                <DownOutlined />
              </Space>
            </Button>
          </Dropdown>
          <Button type="primary" icon={<PlusOutlined />} onClick={handleAddReport}>
            Add Report
          </Button>
        </Space>
      </div>

      {/* 统计卡片 */}
      <Row gutter={16} style={{ marginBottom: 24 }}>
        <Col span={8}>
          <Card>
            <Statistic
              title="Total Reports"
              value={totalReports}
            />
          </Card>
        </Col>
        <Col span={8}>
          <Card>
            <Statistic
              title="Success Rate"
              value={successRate}
              precision={1}
              valueStyle={{ color: '#3f8600' }}
              suffix="%"
            />
          </Card>
        </Col>
        <Col span={8}>
          <Card>
            <Statistic
              title="Avg. Score"
              value={reports.length > 0 ? (reports.reduce((sum, rep) => sum + rep.final_score, 0) / reports.length).toFixed(1) : 0}
              suffix="/100"
            />
          </Card>
        </Col>
      </Row>

      {/* 图表区域 */}
      <Row gutter={16} style={{ marginBottom: 24 }}>
        <Col span={16}>
          <Card title="Score Distribution">
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="name" />
                <YAxis />
                <Tooltip />
                <Legend />
                <Bar dataKey="count" name="Report Count" fill="#1890ff" />
              </BarChart>
            </ResponsiveContainer>
          </Card>
        </Col>
        <Col span={8}>
          <Card title="Success/Failure Ratio">
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie
                  data={[
                    { name: 'PASS', value: Math.round(totalReports * successRate / 100) },
                    { name: 'FAIL', value: Math.round(totalReports * (100 - successRate) / 100) }
                  ]}
                  cx="50%"
                  cy="50%"
                  labelLine={false}
                  outerRadius={80}
                  fill="#8884d8"
                  dataKey="value"
                  label={({ name, percent }) => `${name}: ${(percent * 100).toFixed(0)}%`}
                >
                  {[
                    { name: 'PASS', value: Math.round(totalReports * successRate / 100) },
                    { name: 'FAIL', value: Math.round(totalReports * (100 - successRate) / 100) }
                  ].map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </Card>
        </Col>
      </Row>

      {/* 报告表格 */}
      <Table 
        dataSource={reports} 
        columns={columns} 
        rowKey="id"
        loading={loading}
        pagination={{ pageSize: 10 }}
        onChange={handleTableChange}
      />

      <Modal
        title={editingReport ? 'Edit Report' : 'Add Report'}
        open={modalVisible}
        onOk={handleSaveReport}
        onCancel={() => setModalVisible(false)}
        destroyOnClose
        width={800}
      >
        <Form
          form={form}
          layout="vertical"
          initialValues={editingReport || {}}
        >
          <Form.Item
            name="execution_id"
            label="Execution ID"
            rules={[{ required: true, message: 'Please input the execution ID!' }]}
          >
            <Input />
          </Form.Item>
          <Form.Item
            name="case_id"
            label="Case ID"
            rules={[{ required: true, message: 'Please input the case ID!' }]}
          >
            <Input />
          </Form.Item>
          <Form.Item
            name="final_score"
            label="Final Score"
            rules={[{ required: true, message: 'Please input the final score!' }]}
          >
            <Input type="number" min="0" max="100" />
          </Form.Item>
          <Form.Item
            name="result"
            label="Result"
            rules={[{ required: true, message: 'Please select the result!' }]}
          >
            <Select>
              <Option value="PASS">PASS</Option>
              <Option value="FAIL">FAIL</Option>
            </Select>
          </Form.Item>
          <Form.Item
            name="details"
            label="Details"
          >
            <Input.TextArea rows={4} placeholder="Enter report details" />
          </Form.Item>
        </Form>
      </Modal>
    </div>
  );
};

export default ReportsPage;