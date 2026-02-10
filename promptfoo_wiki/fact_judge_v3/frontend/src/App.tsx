import React from 'react';
import { Layout, Menu, theme } from 'antd';
import { 
  DashboardOutlined, 
  FileTextOutlined, 
  PlayCircleOutlined, 
  BarChartOutlined, 
  UserOutlined 
} from '@ant-design/icons';
import { Routes, Route, Link, useLocation } from 'react-router-dom';

// 页面组件
const DashboardPage = React.lazy(() => import('./pages/Dashboard'));
const CasesPage = React.lazy(() => import('./pages/Cases'));
const ExecutionsPage = React.lazy(() => import('./pages/Executions'));
const ReportsPage = React.lazy(() => import('./pages/Reports'));
const UsersPage = React.lazy(() => import('./pages/Users'));

const { Header, Content, Sider } = Layout;

const App: React.FC = () => {
  const {
    token: { colorBgContainer },
  } = theme.useToken();
  
  const location = useLocation();

  const menuItems = [
    {
      key: '/',
      label: <Link to="/">Dashboard</Link>,
      icon: <DashboardOutlined />,
    },
    {
      key: '/cases',
      label: <Link to="/cases">Test Cases</Link>,
      icon: <FileTextOutlined />,
    },
    {
      key: '/executions',
      label: <Link to="/executions">Executions</Link>,
      icon: <PlayCircleOutlined />,
    },
    {
      key: '/reports',
      label: <Link to="/reports">Reports</Link>,
      icon: <BarChartOutlined />,
    },
    {
      key: '/users',
      label: <Link to="/users">Users</Link>,
      icon: <UserOutlined />,
    },
  ];

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Header className="header" style={{ color: '#fff', fontSize: '18px' }}>
        <div className="logo" style={{ float: 'left', marginRight: '40px' }}>
          Engineering Judge v3
        </div>
      </Header>
      <Layout>
        <Sider width={200} style={{ background: colorBgContainer }}>
          <Menu
            mode="inline"
            selectedKeys={[location.pathname]}
            items={menuItems}
            style={{ height: '100%', borderRight: 0 }}
          />
        </Sider>
        <Layout style={{ padding: '24px' }}>
          <Content
            style={{
              padding: 24,
              margin: 0,
              minHeight: 280,
              background: colorBgContainer,
            }}
          >
            <React.Suspense fallback={<div>Loading...</div>}>
              <Routes>
                <Route path="/" element={<DashboardPage />} />
                <Route path="/cases" element={<CasesPage />} />
                <Route path="/executions" element={<ExecutionsPage />} />
                <Route path="/reports" element={<ReportsPage />} />
                <Route path="/users" element={<UsersPage />} />
              </Routes>
            </React.Suspense>
          </Content>
        </Layout>
      </Layout>
    </Layout>
  );
};

export default App;