import React, { useState, useEffect } from 'react';
import { planApi } from '../api';
import { TestPlan } from '../types';
import PlanList from '../components/PlanList';
import CreatePlanForm from '../components/CreatePlanForm';
import PlanDetail from '../components/PlanDetail';
import { useParams, useNavigate, Routes, Route } from 'react-router-dom';

const PlansPage: React.FC = () => {
  const [plans, setPlans] = useState<TestPlan[]>([]);
  const [selectedPlan, setSelectedPlan] = useState<TestPlan | null>(null);
  const [loading, setLoading] = useState(true);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const { planId } = useParams<{ planId?: string }>();
  const navigate = useNavigate();

  useEffect(() => {
    fetchPlans();
  }, []);

  useEffect(() => {
    if (planId) {
      const numericPlanId = parseInt(planId, 10);
      const selected = plans.find(p => p.id === numericPlanId);
      setSelectedPlan(selected || null);
    } else {
      setSelectedPlan(null);
    }
  }, [planId, plans]);

  const fetchPlans = async () => {
    try {
      setLoading(true);
      const response = await planApi.getAllPlans();
      setPlans(response.data);
    } catch (error) {
      console.error('Failed to fetch plans:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleRunPlan = async (planId: number) => {
    try {
      const response = await planApi.runPlan(planId);
      alert(`Plan ${planId} executed successfully. Report ID: ${response.data.report_id}`);
      // 刷新计划列表以显示最新结果
      fetchPlans();
    } catch (error) {
      console.error(`Failed to run plan ${planId}:`, error);
      alert(`Failed to run plan ${planId}`);
    }
  };

  const handleDeletePlan = async (planId: number) => {
    if (!window.confirm(`Are you sure you want to delete plan ${planId}?`)) {
      return;
    }

    try {
      await planApi.deletePlan(planId);
      alert(`Plan ${planId} deleted successfully`);
      // 刷新计划列表
      fetchPlans();
      if (selectedPlan?.id === planId) {
        setSelectedPlan(null);
        navigate('/plans');
      }
    } catch (error) {
      console.error(`Failed to delete plan ${planId}:`, error);
      alert(`Failed to delete plan ${planId}`);
    }
  };

  const handlePlanCreated = () => {
    setShowCreateForm(false);
    fetchPlans(); // 刷新计划列表
  };

  if (loading) {
    return <div className="container"><p>Loading plans...</p></div>;
  }

  return (
    <div className="container">
      <div className="subpage-nav">
        <ul>
          <li><a href="/plans" className={planId ? '' : 'active'}>All Plans</a></li>
          {selectedPlan && (
            <li><a href={`/plans/${selectedPlan.id}`} className={planId ? 'active' : ''}>{selectedPlan.name}</a></li>
          )}
        </ul>
      </div>

      <h2 className="page-title">Test Plans</h2>

      <div className="card">
        <div className="card-header">
          <h3>Manage Plans</h3>
          <button 
            className="btn btn-success" 
            onClick={() => setShowCreateForm(!showCreateForm)}
          >
            {showCreateForm ? 'Cancel' : 'Create New Plan'}
          </button>
        </div>

        {showCreateForm && (
          <div className="create-form">
            <h4>Create New Test Plan</h4>
            <CreatePlanForm onPlanCreated={handlePlanCreated} />
          </div>
        )}

        <div className="plan-list-container">
          <PlanList 
            plans={plans} 
            onSelectPlan={(testPlan) => {
              setSelectedPlan(testPlan);
              navigate(`/plans/${testPlan.id}`);
            }}
            onRunPlan={handleRunPlan}
            onDeletePlan={handleDeletePlan}
          />
        </div>
      </div>

      <Routes>
        <Route 
          path="/:planId" 
          element={
            <PlanDetail 
              testPlan={selectedPlan} 
              onRunPlan={handleRunPlan}
              onDeletePlan={handleDeletePlan}
            />
          } 
        />
      </Routes>
    </div>
  );
};

export default PlansPage;