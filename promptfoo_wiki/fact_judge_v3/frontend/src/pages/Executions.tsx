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
  Progress,
  DatePicker
} from 'antd';
import { PlusOutlined, PlayCircleOutlined, StopOutlined, PauseCircleOutlined, ClockCircleOutlined } from '@ant-design/icons';
import apiClient from '../utils/api';
import moment from 'moment';

const { Title } = Typography;
const { Option } = Select;

// 定义 Execution 类型
interface ExecutionItem {
  id: string;
  case_id: string;
  case_name?: string; // 案例名称，可能需要从关联数据获取
  status: 'queued' | 'running' | 'completed' | 'failed' | 'stopped' | 'paused';
  progress: number;
  start_time?: string;
  end_time?: string;
  created_at: string;
}

const ExecutionsPage: React.FC = () => {
  const [executions, setExecutions] = useState<ExecutionItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [modalVisible, setModalVisible] = useState(false);
  const [scheduleModalVisible, setScheduleModalVisible] = useState(false);
  const [editingExecution, setEditingExecution] = useState<ExecutionItem | null>(null);
  const [form] = Form.useForm();
  const [scheduleForm] = Form.useForm();

  // 模拟获取执行列表
  useEffect(() => {
    fetchExecutions();
  }, []);

  const fetchExecutions = async () => {
    setLoading(true);
    try {
      // 模拟 API 调用
      setTimeout(() => {
        setExecutions([
          { id: 'exec-001', case_id: 'case-001', case_name: 'Java Controller Eval', status: 'completed', progress: 100, start_time: '2026-02-10T09:30:00', end_time: '2026-02-10T09:45:00', created_at: '2026-02-10T09:30:00' },
          { id: 'exec-002', case_id: 'case-002', case_name: 'SQL Procedure Eval', status: 'running', progress: 65, start_time: '2026-02-10T10:00:00', created_at: '2026-02-10T10:00:00' },
          { id: 'exec-003', case_id: 'case-003', case_name: 'Python Module Eval', status: 'queued', progress: 0, created_at: '2026-02-10T08:45:00' },
          { id: 'exec-004', case_id: 'case-001', case_name: 'Java Controller Eval', status: 'failed', progress: 30, start_time: '2026-02-10T07:30:00', end_time: '2026-02-10T07:45:00', created_at: '2026-02-10T07:30:00' },
        ]);
        setLoading(false);
      }, 500);
    } catch (error) {
      console.error('Failed to fetch executions:', error);
      message.error('Failed to fetch executions');
      setLoading(false);
    }
  };

  const handleStartExecution = () => {
    setEditingExecution(null);
    form.resetFields();
    setModalVisible(true);
  };

  const handleEditExecution = (record: ExecutionItem) => {
    setEditingExecution(record);
    form.setFieldsValue(record);
    setModalVisible(true);
  };

  const handleStopExecution = async (id: string) => {
    try {
      // 实际的停止执行 API 调用
      // await apiClient.put(`/executions/${id}/stop`);
      message.success('Execution stopped successfully');
      fetchExecutions(); // 重新获取列表
    } catch (error) {
      console.error('Failed to stop execution:', error);
      message.error('Failed to stop execution');
    }
  };

  const handlePauseExecution = async (id: string) => {
    try {
      // 实际的暂停执行 API 调用
      // await apiClient.put(`/executions/${id}/pause`);
      message.success('Execution paused successfully');
      fetchExecutions(); // 重新获取列表
    } catch (error) {
      console.error('Failed to pause execution:', error);
      message.error('Failed to pause execution');
    }
  };

  const handleSaveExecution = async () => {
    try {
      const values = await form.validateFields();
      
      if (editingExecution) {
        // 更新现有执行
        // await apiClient.put(`/executions/${editingExecution.id}`, values);
      } else {
        // 创建新执行
        // await apiClient.post('/executions', values);
      }
      
      message.success(`Execution ${editingExecution ? 'updated' : 'created'} successfully`);
      setModalVisible(false);
      fetchExecutions(); // 重新获取列表
    } catch (error) {
      console.error('Failed to save execution:', error);
      message.error('Failed to save execution');
    }
  };

  const handleScheduleExecution = () => {
    scheduleForm.resetFields();
    setScheduleModalVisible(true);
  };

  const handleScheduleSubmit = async () => {
    try {
      const values = await scheduleForm.validateFields();
      
      // 调用调度执行 API
      // const response = await apiClient.post('/executions/schedule', {
      //   ...values,
      //   scheduled_time: values.scheduled_time.format('YYYY-MM-DDTHH:mm:ss')
      // });
      
      message.success('Execution scheduled successfully');
      setScheduleModalVisible(false);
      fetchExecutions(); // 重新获取列表
    } catch (error) {
      console.error('Failed to schedule execution:', error);
      message.error('Failed to schedule execution');
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'completed': return 'green';
      case 'running': return 'blue';
      case 'queued': return 'orange';
      case 'failed': return 'red';
      case 'stopped': return 'gray';
      case 'paused': return 'purple';
      default: return 'default';
    }
  };

  const columns = [
    {
      title: 'ID',
      dataIndex: 'id',
      key: 'id',
    },
    {
      title: 'Case Name',
      dataIndex: 'case_name',
      key: 'case_name',
    },
    {
      title: 'Status',
      dataIndex: 'status',
      key: 'status',
      render: (status: string) => (
        <Tag color={getStatusColor(status)}>
          {status.charAt(0).toUpperCase() + status.slice(1)}
        </Tag>
      ),
    },
    {
      title: 'Progress',
      dataIndex: 'progress',
      key: 'progress',
      render: (progress: number) => (
        <div>
          <Progress percent={progress} size="small" />
          <span>{progress}%</span>
        </div>
      ),
    },
    {
      title: 'Start Time',
      dataIndex: 'start_time',
      key: 'start_time',
      render: (time: string) => time ? new Date(time).toLocaleString() : '-',
    },
    {
      title: 'End Time',
      dataIndex: 'end_time',
      key: 'end_time',
      render: (time: string) => time ? new Date(time).toLocaleString() : '-',
    },
    {
      title: 'Created At',
      dataIndex: 'created_at',
      key: 'created_at',
      render: (time: string) => new Date(time).toLocaleString(),
    },
    {
      title: 'Actions',
      key: 'actions',
      render: (_: any, record: ExecutionItem) => (
        <Space>
          {record.status === 'running' && (
            <>
              <Button icon={<PauseCircleOutlined />} onClick={() => handlePauseExecution(record.id)}>
                Pause
              </Button>
              <Button danger icon={<StopOutlined />} onClick={() => handleStopExecution(record.id)}>
                Stop
              </Button>
            </>
          )}
          {(record.status === 'queued' || record.status === 'paused') && (
            <Button type="primary" icon={<PlayCircleOutlined />} onClick={() => handleEditExecution(record)}>
              Resume
            </Button>
          )}
          {record.status === 'completed' && (
            <Button onClick={() => handleEditExecution(record)}>
              View
            </Button>
          )}
        </Space>
      ),
    },
  ];

  return (
    <div>
      <div style={{ marginBottom: 16, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Title level={2}>Executions</Title>
        <Space>
          <Button type="primary" icon={<ClockCircleOutlined />} onClick={handleScheduleExecution}>
            Schedule Execution
          </Button>
          <Button type="primary" icon={<PlusOutlined />} onClick={handleStartExecution}>
            Start New Execution
          </Button>
        </Space>
      </div>

      <Table 
        dataSource={executions} 
        columns={columns} 
        rowKey="id"
        loading={loading}
        pagination={{ pageSize: 10 }}
      />

      <Modal
        title={editingExecution ? 'Edit Execution' : 'Start New Execution'}
        open={modalVisible}
        onOk={handleSaveExecution}
        onCancel={() => setModalVisible(false)}
        destroyOnClose
      >
        <Form
          form={form}
          layout="vertical"
          initialValues={editingExecution || {}}
        >
          <Form.Item
            name="case_id"
            label="Case ID"
            rules={[{ required: true, message: 'Please select a case!' }]}
          >
            <Select placeholder="Select a case">
              <Option value="case-001">Java Controller Eval</Option>
              <Option value="case-002">SQL Procedure Eval</Option>
              <Option value="case-003">Python Module Eval</Option>
            </Select>
          </Form.Item>
          <Form.Item
            name="status"
            label="Status"
            rules={[{ required: true, message: 'Please select the status!' }]}
          >
            <Select>
              <Option value="queued">Queued</Option>
              <Option value="running">Running</Option>
              <Option value="paused">Paused</Option>
            </Select>
          </Form.Item>
        </Form>
      </Modal>

      <Modal
        title="Schedule Execution"
        open={scheduleModalVisible}
        onOk={handleScheduleSubmit}
        onCancel={() => setScheduleModalVisible(false)}
        destroyOnClose
      >
        <Form
          form={scheduleForm}
          layout="vertical"
        >
          <Form.Item
            name="case_id"
            label="Case ID"
            rules={[{ required: true, message: 'Please select a case!' }]}
          >
            <Select placeholder="Select a case">
              <Option value="case-001">Java Controller Eval</Option>
              <Option value="case-002">SQL Procedure Eval</Option>
              <Option value="case-003">Python Module Eval</Option>
            </Select>
          </Form.Item>
          <Form.Item
            name="scheduled_time"
            label="Scheduled Time"
            rules={[{ required: true, message: 'Please select a time!' }]}
          >
            <DatePicker showTime />
          </Form.Item>
        </Form>
      </Modal>
    </div>
  );
};

export default ExecutionsPage;