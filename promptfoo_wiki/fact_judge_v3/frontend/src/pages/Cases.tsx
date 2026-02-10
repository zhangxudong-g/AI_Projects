import React, { useState, useEffect } from 'react';
import { 
  Table, 
  Button, 
  Modal, 
  Form, 
  Input, 
  Space, 
  Tag,
  Typography,
  message,
  Upload,
  Select
} from 'antd';
import { PlusOutlined, UploadOutlined } from '@ant-design/icons';
import apiClient from '../utils/api';

const { Title } = Typography;

// 定义 Case 类型
interface CaseItem {
  id: string;
  name: string;
  description?: string;
  createdAt: string;
  updatedAt: string;
  status: 'active' | 'inactive';
}

const CasesPage: React.FC = () => {
  const [cases, setCases] = useState<CaseItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [modalVisible, setModalVisible] = useState(false);
  const [importModalVisible, setImportModalVisible] = useState(false);
  const [editingCase, setEditingCase] = useState<CaseItem | null>(null);
  const [form] = Form.useForm();

  // 获取测试案例列表
  useEffect(() => {
    fetchCases();
  }, []);

  const fetchCases = async () => {
    setLoading(true);
    try {
      const response = await apiClient.get('/cases');
      setCases(response.data);
    } catch (error) {
      console.error('Failed to fetch cases:', error);
      message.error('Failed to fetch cases');
      
      // 如果API调用失败，使用模拟数据作为后备
      setCases([
        { id: 'case-001', name: 'Java Controller Evaluation', description: 'Evaluates Java controller documentation', createdAt: '2026-02-01', updatedAt: '2026-02-05', status: 'active' },
        { id: 'case-002', name: 'SQL Procedure Documentation', description: 'Checks SQL procedure documentation quality', createdAt: '2026-02-02', updatedAt: '2026-02-08', status: 'active' },
        { id: 'case-003', name: 'Python Module Analysis', description: 'Analyzes Python module documentation', createdAt: '2026-02-03', updatedAt: '2026-02-03', status: 'inactive' },
      ]);
    } finally {
      setLoading(false);
    }
  };

  const handleAddCase = () => {
    setEditingCase(null);
    form.resetFields();
    setModalVisible(true);
  };

  const handleEditCase = (record: CaseItem) => {
    setEditingCase(record);
    form.setFieldsValue(record);
    setModalVisible(true);
  };

  const handleDeleteCase = async (id: string) => {
    try {
      await apiClient.delete(`/cases/${id}`);
      message.success('Case deleted successfully');
      fetchCases(); // 重新获取列表
    } catch (error) {
      console.error('Failed to delete case:', error);
      message.error('Failed to delete case');
    }
  };

  const handleSaveCase = async () => {
    try {
      const values = await form.validateFields();

      if (editingCase) {
        // 更新现有案例
        await apiClient.put(`/cases/${editingCase.id}`, values);
      } else {
        // 创建新案例
        await apiClient.post('/cases', values);
      }

      message.success(`Case ${editingCase ? 'updated' : 'created'} successfully`);
      setModalVisible(false);
      fetchCases(); // 重新获取列表
    } catch (error) {
      console.error('Failed to save case:', error);
      message.error('Failed to save case');
    }
  };

  const handleImportModalOpen = () => {
    setImportModalVisible(true);
  };

  const handleImportSubmit = async (file: any) => {
    try {
      const formData = new FormData();
      formData.append('file', file.file.originFileObj);
      
      const response = await apiClient.post('/cases/import', formData, {
        headers: {
          'Content-Type': 'multipart/form-data'
        }
      });

      message.success('Cases imported successfully');
      setImportModalVisible(false);
      fetchCases(); // 重新获取列表
    } catch (error) {
      console.error('Failed to import cases:', error);
      message.error('Failed to import cases');
    }
  };

  const beforeUpload = (file: any) => {
    const isSupportedFormat = file.type === 'application/json' || 
                              file.name.endsWith('.yaml') || 
                              file.name.endsWith('.yml');
    if (!isSupportedFormat) {
      message.error('You can only upload JSON, YAML or YML files!');
    }
    return isSupportedFormat;
  };

  const columns = [
    {
      title: 'ID',
      dataIndex: 'id',
      key: 'id',
    },
    {
      title: 'Name',
      dataIndex: 'name',
      key: 'name',
    },
    {
      title: 'Description',
      dataIndex: 'description',
      key: 'description',
    },
    {
      title: 'Status',
      dataIndex: 'status',
      key: 'status',
      render: (status: 'active' | 'inactive') => (
        <Tag color={status === 'active' ? 'green' : 'red'}>
          {status.charAt(0).toUpperCase() + status.slice(1)}
        </Tag>
      ),
    },
    {
      title: 'Created At',
      dataIndex: 'createdAt',
      key: 'createdAt',
    },
    {
      title: 'Actions',
      key: 'actions',
      render: (_: any, record: CaseItem) => (
        <Space>
          <Button onClick={() => handleEditCase(record)}>Edit</Button>
          <Button danger onClick={() => handleDeleteCase(record.id)}>Delete</Button>
        </Space>
      ),
    },
  ];

  return (
    <div>
      <div style={{ marginBottom: 16, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Title level={2}>Test Cases</Title>
        <Space>
          <Button type="default" icon={<UploadOutlined />} onClick={handleImportModalOpen}>
            Import Cases
          </Button>
          <Button type="primary" icon={<PlusOutlined />} onClick={handleAddCase}>
            Add Case
          </Button>
        </Space>
      </div>

      <Table 
        dataSource={cases} 
        columns={columns} 
        rowKey="id"
        loading={loading}
        pagination={{ pageSize: 10 }}
      />

      <Modal
        title={editingCase ? 'Edit Case' : 'Add Case'}
        open={modalVisible}
        onOk={handleSaveCase}
        onCancel={() => setModalVisible(false)}
        destroyOnClose
      >
        <Form
          form={form}
          layout="vertical"
          initialValues={editingCase || {}}
        >
          <Form.Item
            name="name"
            label="Name"
            rules={[{ required: true, message: 'Please input the case name!' }]}
          >
            <Input />
          </Form.Item>
          <Form.Item
            name="description"
            label="Description"
          >
            <Input.TextArea rows={4} />
          </Form.Item>
          <Form.Item
            name="status"
            label="Status"
            rules={[{ required: true, message: 'Please select the status!' }]}
          >
            <Input /> {/* 在实际实现中，这里应该是 Select 组件 */}
          </Form.Item>
        </Form>
      </Modal>

      <Modal
        title="Import Cases"
        open={importModalVisible}
        onCancel={() => setImportModalVisible(false)}
        footer={null}
        destroyOnClose
      >
        <Upload
          name="file"
          beforeUpload={beforeUpload}
          onChange={async (info) => {
            if (info.file.status !== 'uploading') {
              console.log(info.file, info.fileList);
            }
            if (info.file.status === 'done') {
              message.success(`${info.file.name} file uploaded successfully`);
              setImportModalVisible(false);
              fetchCases(); // 重新获取列表
            } else if (info.file.status === 'error') {
              message.error(`${info.file.name} file upload failed.`);
            }
          }}
          accept=".json,.yaml,.yml"
          customRequest={async (options) => {
            const { onSuccess, onError, file } = options;
            const formData = new FormData();
            formData.append('file', file);

            try {
              const response = await apiClient.post('/cases/import', formData, {
                headers: {
                  'Content-Type': 'multipart/form-data'
                }
              });
              
              onSuccess(response.data, file);
            } catch (error) {
              onError(error);
            }
          }}
        >
          <Button icon={<UploadOutlined />}>Click to Upload JSON/YAML</Button>
        </Upload>
        <div style={{ marginTop: 16 }}>
          <Typography.Text type="secondary">
            Supported formats: JSON, YAML (.yml or .yaml)<br/>
            File should contain an array of case definitions.
          </Typography.Text>
        </div>
      </Modal>
    </div>
  );
};

export default CasesPage;