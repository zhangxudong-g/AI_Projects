import React, { useState, useEffect } from 'react';
import { caseApi } from '../api';
import { TestCase } from '../types';
import CaseList from '../components/CaseList';
import UploadCaseForm from '../components/UploadCaseForm';
import CaseDetail from '../components/CaseDetail';
import { useParams, useNavigate, Routes, Route } from 'react-router-dom';

const CasesPage: React.FC = () => {
  const [cases, setCases] = useState<TestCase[]>([]);
  const [selectedCase, setSelectedCase] = useState<TestCase | null>(null);
  const [loading, setLoading] = useState(true);
  const [showUploadForm, setShowUploadForm] = useState(false);
  const { caseId } = useParams<{ caseId?: string }>();
  const navigate = useNavigate();

  useEffect(() => {
    fetchCases();
  }, []);

  useEffect(() => {
    if (caseId) {
      const selected = cases.find(c => c.case_id === caseId);
      setSelectedCase(selected || null);
    } else {
      setSelectedCase(null);
    }
  }, [caseId, cases]);

  const fetchCases = async () => {
    try {
      setLoading(true);
      const response = await caseApi.getAllCases();
      setCases(response.data);
    } catch (error) {
      console.error('Failed to fetch cases:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleRunCase = async (caseId: string) => {
    try {
      const response = await caseApi.runCase(caseId);
      alert(`Case ${caseId} executed successfully. Report ID: ${response.data.report_id}`);
      // 刷新案例列表以显示最新结果
      fetchCases();
    } catch (error) {
      console.error(`Failed to run case ${caseId}:`, error);
      alert(`Failed to run case ${caseId}`);
    }
  };

  const handleDeleteCase = async (caseId: string) => {
    if (!window.confirm(`Are you sure you want to delete case ${caseId}?`)) {
      return;
    }

    try {
      await caseApi.deleteCase(caseId);
      alert(`Case ${caseId} deleted successfully`);
      // 刷新案例列表
      fetchCases();
      if (selectedCase?.case_id === caseId) {
        setSelectedCase(null);
        navigate('/cases');
      }
    } catch (error) {
      console.error(`Failed to delete case ${caseId}:`, error);
      alert(`Failed to delete case ${caseId}`);
    }
  };

  const handleBulkDeleteCases = async (caseIds: string[]) => {
    try {
      const response = await caseApi.bulkDeleteCases(caseIds);
      const deletedCount = response.data.length;
      alert(`${deletedCount} case(s) deleted successfully`);
      // 刷新案例列表
      fetchCases();
      // 如果已选中的案例被删除，则清除选择
      if (selectedCase && caseIds.includes(selectedCase.case_id)) {
        setSelectedCase(null);
        navigate('/cases');
      }
    } catch (error: any) {
      console.error(`Failed to bulk delete cases:`, error);
      let errorMessage = 'Failed to bulk delete cases';
      if (error.response?.data?.detail) {
        errorMessage = error.response.data.detail;
      } else if (error.message) {
        errorMessage = error.message;
      }
      alert(errorMessage);
    }
  };

  const handleCaseUpdated = (updatedCase: TestCase) => {
    // 更新本地状态中的案例信息
    setCases(prevCases => 
      prevCases.map(caseItem => 
        caseItem.case_id === updatedCase.case_id ? updatedCase : caseItem
      )
    );
    
    // 如果当前选中的案例被更新，也要更新选中的案例
    if (selectedCase && selectedCase.case_id === updatedCase.case_id) {
      setSelectedCase(updatedCase);
    }
  };

  const handleCaseUploaded = () => {
    setShowUploadForm(false);
    fetchCases(); // 刷新案例列表
  };

  if (loading) {
    return <div className="container"><p>Loading cases...</p></div>;
  }

  return (
    <div className="container">
      <div className="subpage-nav">
        <ul>
          <li><a href="/cases" className={caseId ? '' : 'active'}>All Cases</a></li>
          {selectedCase && (
            <li><a href={`/cases/${selectedCase.case_id}`} className={caseId ? 'active' : ''}>{selectedCase.name}</a></li>
          )}
        </ul>
      </div>

      <h2 className="page-title">Test Cases</h2>

      <div className="card">
        <div className="card-header">
          <h3>Manage Cases</h3>
          <button 
            className="btn btn-success" 
            onClick={() => setShowUploadForm(!showUploadForm)}
          >
            {showUploadForm ? 'Cancel' : 'Upload New Case'}
          </button>
        </div>

        {showUploadForm && (
          <div className="upload-form">
            <h4>Upload New Test Case</h4>
            <UploadCaseForm onUploadSuccess={handleCaseUploaded} />
          </div>
        )}

        <div className="case-list-container">
          <CaseList
            cases={cases}
            onSelectCase={(testCase) => {
              setSelectedCase(testCase);
              navigate(`/cases/${testCase.case_id}`);
            }}
            onRunCase={handleRunCase}
            onDeleteCase={handleDeleteCase}
            onBulkDelete={handleBulkDeleteCases}
          />
        </div>
      </div>

      <Routes>
        <Route
          path="/:caseId"
          element={
            <CaseDetail
              testCase={selectedCase}
              onRunCase={handleRunCase}
              onDeleteCase={handleDeleteCase}
              onCaseUpdated={handleCaseUpdated}
            />
          }
        />
      </Routes>
    </div>
  );
};

export default CasesPage;