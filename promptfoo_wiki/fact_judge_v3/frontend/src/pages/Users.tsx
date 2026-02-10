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
  Tabs,
  Card
} from 'antd';
import { PlusOutlined, UserOutlined, HistoryOutlined } from '@ant-design/icons';
import apiClient from '../utils/api';

const { TabPane } = Tabs;

const { Title } = Typography;
const { Option } = Select;

// 定义 User 类型
interface UserItem {
  id: string;
  username: string;
  email: string;
  role: 'admin' | 'user' | 'viewer';
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

const UsersPage: React.FC = () => {
  const [users, setUsers] = useState<UserItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [modalVisible, setModalVisible] = useState(false);
  const [profileModalVisible, setProfileModalVisible] = useState(false);
  const [activityModalVisible, setActivityModalVisible] = useState(false);
  const [editingUser, setEditingUser] = useState<UserItem | null>(null);
  const [currentUserProfile, setCurrentUserProfile] = useState<UserItem | null>(null);
  const [activityLogs, setActivityLogs] = useState<any[]>([]);
  const [form] = Form.useForm();
  const [profileForm] = Form.useForm();

  // 模拟获取用户列表
  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchCurrentUserProfile = async () => {
    try {
      // 模拟获取当前用户资料
      // const response = await apiClient.get('/users/profile');
      const mockProfile = {
        id: 'current-user-id',
        username: 'current_user',
        email: 'current@example.com',
        role: 'admin',
        is_active: true,
        created_at: '2026-01-15',
        updated_at: '2026-02-10'
      };
      setCurrentUserProfile(mockProfile);
      profileForm.setFieldsValue(mockProfile);
    } catch (error) {
      console.error('Failed to fetch profile:', error);
      message.error('Failed to fetch profile');
    }
  };

  const fetchActivityLogs = async () => {
    try {
      // 模拟获取活动日志
      // const response = await apiClient.get('/users/activity-log');
      const mockLogs = [
        { id: 'log-001', action: 'login', timestamp: '2026-02-10T10:30:00', details: 'Successful login' },
        { id: 'log-002', action: 'create_case', timestamp: '2026-02-10T09:45:00', details: 'Created new test case' },
        { id: 'log-003', action: 'run_execution', timestamp: '2026-02-10T08:30:00', details: 'Started execution for case-001' },
        { id: 'log-004', action: 'logout', timestamp: '2026-02-09T18:15:00', details: 'User logged out' },
      ];
      setActivityLogs(mockLogs);
    } catch (error) {
      console.error('Failed to fetch activity logs:', error);
      message.error('Failed to fetch activity logs');
    }
  };

  const fetchUsers = async () => {
    setLoading(true);
    try {
      // 模拟 API 调用
      setTimeout(() => {
        setUsers([
          { id: 'user-001', username: 'admin', email: 'admin@example.com', role: 'admin', is_active: true, created_at: '2026-01-15', updated_at: '2026-02-10' },
          { id: 'user-002', username: 'john_doe', email: 'john@example.com', role: 'user', is_active: true, created_at: '2026-01-20', updated_at: '2026-02-05' },
          { id: 'user-003', username: 'jane_smith', email: 'jane@example.com', role: 'viewer', is_active: false, created_at: '2026-02-01', updated_at: '2026-02-01' },
        ]);
        setLoading(false);
      }, 500);
    } catch (error) {
      console.error('Failed to fetch users:', error);
      message.error('Failed to fetch users');
      setLoading(false);
    }
  };

  const handleAddUser = () => {
    setEditingUser(null);
    form.resetFields();
    setModalVisible(true);
  };

  const handleEditUser = (record: UserItem) => {
    setEditingUser(record);
    form.setFieldsValue(record);
    setModalVisible(true);
  };

  const handleDeleteUser = async (id: string) => {
    try {
      // 实际的删除 API 调用
      // await apiClient.delete(`/users/${id}`);
      message.success('User deleted successfully');
      fetchUsers(); // 重新获取列表
    } catch (error) {
      console.error('Failed to delete user:', error);
      message.error('Failed to delete user');
    }
  };

  const handleSaveUser = async () => {
    try {
      const values = await form.validateFields();
      
      if (editingUser) {
        // 更新现有用户
        // await apiClient.put(`/users/${editingUser.id}`, values);
      } else {
        // 创建新用户
        // await apiClient.post('/users', values);
      }
      
      message.success(`User ${editingUser ? 'updated' : 'created'} successfully`);
      setModalVisible(false);
      fetchUsers(); // 重新获取列表
    } catch (error) {
      console.error('Failed to save user:', error);
      message.error('Failed to save user');
    }
  };

  const handleViewProfile = () => {
    fetchCurrentUserProfile();
    setProfileModalVisible(true);
  };

  const handleViewActivity = () => {
    fetchActivityLogs();
    setActivityModalVisible(true);
  };

  const handleUpdateProfile = async () => {
    try {
      const values = await profileForm.validateFields();
      
      // 更新用户资料
      // await apiClient.put('/users/profile', values);
      
      message.success('Profile updated successfully');
      setProfileModalVisible(false);
    } catch (error) {
      console.error('Failed to update profile:', error);
      message.error('Failed to update profile');
    }
  };

  const columns = [
    {
      title: 'ID',
      dataIndex: 'id',
      key: 'id',
    },
    {
      title: 'Username',
      dataIndex: 'username',
      key: 'username',
    },
    {
      title: 'Email',
      dataIndex: 'email',
      key: 'email',
    },
    {
      title: 'Role',
      dataIndex: 'role',
      key: 'role',
      render: (role: string) => (
        <Tag color={
          role === 'admin' ? 'red' : 
          role === 'user' ? 'blue' : 
          'orange'
        }>
          {role.charAt(0).toUpperCase() + role.slice(1)}
        </Tag>
      ),
    },
    {
      title: 'Status',
      dataIndex: 'is_active',
      key: 'is_active',
      render: (isActive: boolean) => (
        <Tag color={isActive ? 'green' : 'red'}>
          {isActive ? 'Active' : 'Inactive'}
        </Tag>
      ),
    },
    {
      title: 'Created At',
      dataIndex: 'created_at',
      key: 'created_at',
    },
    {
      title: 'Updated At',
      dataIndex: 'updated_at',
      key: 'updated_at',
    },
    {
      title: 'Actions',
      key: 'actions',
      render: (_: any, record: UserItem) => (
        <Space>
          <Button onClick={() => handleEditUser(record)}>Edit</Button>
          <Button danger onClick={() => handleDeleteUser(record.id)}>Delete</Button>
        </Space>
      ),
    },
  ];

  return (
    <div>
      <div style={{ marginBottom: 16, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Title level={2}>Users</Title>
        <Space>
          <Button icon={<UserOutlined />} onClick={handleViewProfile}>
            My Profile
          </Button>
          <Button icon={<HistoryOutlined />} onClick={handleViewActivity}>
            Activity Log
          </Button>
          <Button type="primary" icon={<PlusOutlined />} onClick={handleAddUser}>
            Add User
          </Button>
        </Space>
      </div>

      <Table 
        dataSource={users} 
        columns={columns} 
        rowKey="id"
        loading={loading}
        pagination={{ pageSize: 10 }}
      />

      <Modal
        title={editingUser ? 'Edit User' : 'Add User'}
        open={modalVisible}
        onOk={handleSaveUser}
        onCancel={() => setModalVisible(false)}
        destroyOnClose
      >
        <Form
          form={form}
          layout="vertical"
          initialValues={editingUser || {}}
        >
          <Form.Item
            name="username"
            label="Username"
            rules={[{ required: true, message: 'Please input the username!' }]}
          >
            <Input />
          </Form.Item>
          <Form.Item
            name="email"
            label="Email"
            rules={[
              { required: true, message: 'Please input the email!' },
              { type: 'email', message: 'Please enter a valid email!' }
            ]}
          >
            <Input />
          </Form.Item>
          <Form.Item
            name="role"
            label="Role"
            rules={[{ required: true, message: 'Please select the role!' }]}
          >
            <Select>
              <Option value="admin">Admin</Option>
              <Option value="user">User</Option>
              <Option value="viewer">Viewer</Option>
            </Select>
          </Form.Item>
          <Form.Item
            name="is_active"
            label="Status"
            valuePropName="checked"
          >
            <Select>
              <Option value={true}>Active</Option>
              <Option value={false}>Inactive</Option>
            </Select>
          </Form.Item>
          {!editingUser && (
            <Form.Item
              name="password"
              label="Password"
              rules={[{ required: !editingUser, message: 'Please input the password!' }]}
            >
              <Input.Password />
            </Form.Item>
          )}
        </Form>
      </Modal>

      <Modal
        title="My Profile"
        open={profileModalVisible}
        onOk={handleUpdateProfile}
        onCancel={() => setProfileModalVisible(false)}
        destroyOnClose
        width={600}
      >
        <Tabs defaultActiveKey="profile">
          <TabPane tab="Profile Info" key="profile">
            <Form
              form={profileForm}
              layout="vertical"
            >
              <Form.Item
                name="username"
                label="Username"
                rules={[{ required: true, message: 'Please input the username!' }]}
              >
                <Input />
              </Form.Item>
              <Form.Item
                name="email"
                label="Email"
                rules={[
                  { required: true, message: 'Please input the email!' },
                  { type: 'email', message: 'Please enter a valid email!' }
                ]}
              >
                <Input />
              </Form.Item>
              <Form.Item
                name="role"
                label="Role"
              >
                <Input disabled />
              </Form.Item>
            </Form>
          </TabPane>
          <TabPane tab="Preferences" key="preferences">
            <Card title="Personal Preferences">
              <Form layout="vertical">
                <Form.Item label="Theme">
                  <Select defaultValue="light">
                    <Option value="light">Light</Option>
                    <Option value="dark">Dark</Option>
                  </Select>
                </Form.Item>
                <Form.Item label="Language">
                  <Select defaultValue="en">
                    <Option value="en">English</Option>
                    <Option value="zh">中文</Option>
                  </Select>
                </Form.Item>
                <Form.Item label="Notifications">
                  <Space direction="vertical">
                    <Form.Item valuePropName="checked" noStyle>
                      <Input type="checkbox" /> Email Notifications
                    </Form.Item>
                    <Form.Item valuePropName="checked" noStyle>
                      <Input type="checkbox" /> In-App Notifications
                    </Form.Item>
                  </Space>
                </Form.Item>
              </Form>
            </Card>
          </TabPane>
        </Tabs>
      </Modal>

      <Modal
        title="Activity Log"
        open={activityModalVisible}
        onCancel={() => setActivityModalVisible(false)}
        footer={null}
        destroyOnClose
        width={800}
      >
        <Table
          dataSource={activityLogs}
          columns={[
            {
              title: 'Action',
              dataIndex: 'action',
              key: 'action',
            },
            {
              title: 'Timestamp',
              dataIndex: 'timestamp',
              key: 'timestamp',
              render: (time: string) => new Date(time).toLocaleString(),
            },
            {
              title: 'Details',
              dataIndex: 'details',
              key: 'details',
            }
          ]}
          rowKey="id"
          pagination={{ pageSize: 10 }}
        />
      </Modal>
    </div>
  );
};

export default UsersPage;