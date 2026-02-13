import React, { useState, useEffect } from 'react';
import { TestPlan, ExtendedTestPlan, PlanSummary } from '../types';
import { reportApi } from '../api';

interface PlanListProps {
  plans: TestPlan[];
  onSelectPlan: (testPlan: TestPlan) => void;
  onRunPlan: (planId: number) => void;
  onDeletePlan: (planId: number) => void;
  onBulkDelete: (planIds: number[]) => void;
}

const PlanList: React.FC<PlanListProps> = ({ plans, onSelectPlan, onRunPlan, onDeletePlan, onBulkDelete }) => {
  const [selectedPlans, setSelectedPlans] = useState<number[]>([]);
  const [deleting, setDeleting] = useState(false);
  const [planSummaries, setPlanSummaries] = useState<Record<number, PlanSummary>>({});
  const [loadingSummaries, setLoadingSummaries] = useState<Set<number>>(new Set());
  const [realtimeStatus, setRealtimeStatus] = useState<Record<number, any>>({});

  // 获取所有计划的汇总信息
  useEffect(() => {
    const fetchAllSummaries = async () => {
      // 重置状态
      setPlanSummaries({});
      setLoadingSummaries(new Set(plans.map(p => p.id)));

      // 并行获取所有计划的汇总信息
      const summaryPromises = plans.map(async (plan) => {
        try {
          const response = await reportApi.getPlanSummary(plan.id);
          return { planId: plan.id, summary: response.data };
        } catch (error) {
          // 如果获取汇总信息失败，使用默认值
          return {
            planId: plan.id,
            summary: {
              plan_id: plan.id,
              total_reports: 0,
              completed_reports: 0,
              failed_reports: 0,
              average_score: null,
              max_score: null,
              min_score: null,
              summary: 'No reports available'
            }
          };
        }
      });

      const results = await Promise.all(summaryPromises);

      // 构建汇总信息映射
      const summariesMap: Record<number, PlanSummary> = {};
      results.forEach(({ planId, summary }) => {
        summariesMap[planId] = summary;
      });

      setPlanSummaries(summariesMap);
      setLoadingSummaries(new Set());
    };

    if (plans.length > 0) {
      fetchAllSummaries();
    }
  }, [plans]);


  if (plans.length === 0) {
    return <p>No test plans found.</p>;
  }

  const handleSelectAll = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.checked) {
      setSelectedPlans(plans.map(plan => plan.id));
    } else {
      setSelectedPlans([]);
    }
  };

  const handleSingleSelect = (id: number, checked: boolean) => {
    if (checked) {
      setSelectedPlans(prev => [...prev, id]);
    } else {
      setSelectedPlans(prev => prev.filter(planId => planId !== id));
    }
  };

  const handleBulkDelete = () => {
    if (selectedPlans.length > 0) {
      const planNames = selectedPlans.slice(0, 5).map(id =>
        plans.find(p => p.id === id)?.name || `Plan ${id}`
      ).join(', ');
      const extraCount = selectedPlans.length - 5;

      let confirmationMessage = `Are you sure you want to delete ${selectedPlans.length} plan(s)?`;
      if (selectedPlans.length > 5) {
        confirmationMessage += `\n\nSelected plans: ${planNames} and ${extraCount} more.`;
      } else {
        confirmationMessage += `\n\nSelected plans: ${planNames}`;
      }

      if (window.confirm(confirmationMessage)) {
        setDeleting(true);
        onBulkDelete(selectedPlans);
      }
    } else {
      alert('Please select at least one plan to delete.');
    }
  };

  return (
    <div className="plan-list">
      <div className="table-header">
        <div className="bulk-actions">
          <button
            className="btn btn-danger"
            onClick={handleBulkDelete}
            disabled={selectedPlans.length === 0 || deleting}
          >
            {deleting ? 'Deleting...' : `Bulk Delete (${selectedPlans.length})`}
          </button>
        </div>
      </div>

      <table className="table">
        <thead>
          <tr>
            <th className="col-checkbox">
              <input
                type="checkbox"
                onChange={handleSelectAll}
                checked={selectedPlans.length === plans.length && plans.length > 0}
              />
            </th>
            <th className="col-id">ID</th>
            <th className="col-name">Name</th>
            <th className="col-description">Description</th>
            <th className="col-created">Created At</th>
            <th className="col-summary">Summary</th>
            <th className="col-actions">Actions</th>
          </tr>
        </thead>
        <tbody>
          {plans.map((testPlan) => {
            const summary = planSummaries[testPlan.id];
            const isLoading = loadingSummaries.has(testPlan.id);
            
            return (
              <tr key={testPlan.id}>
                <td>
                  <input
                    type="checkbox"
                    checked={selectedPlans.includes(testPlan.id)}
                    onChange={(e) => handleSingleSelect(testPlan.id, e.target.checked)}
                  />
                </td>
                <td>{testPlan.id}</td>
                <td title={testPlan.name}>{testPlan.name}</td>
                <td title={testPlan.description || '-'}>{testPlan.description || '-'}</td>
                <td>{new Date(testPlan.created_at).toLocaleString()}</td>
                <td className="summary-cell">
                  {isLoading ? (
                    <span className="loading">Loading...</span>
                  ) : summary ? (
                    <div className="summary-content">
                      <div className="summary-stats">
                        <span className="stat-badge stat-completed" title="Completed reports">
                          ✓ {summary.completed_reports}
                        </span>
                        <span className="stat-badge stat-failed" title="Failed reports">
                          ✗ {summary.failed_reports}
                        </span>
                        <span className="stat-badge stat-average" title="Average score">
                          AVG {summary.average_score !== null ? summary.average_score.toFixed(2) : 'N/A'}
                        </span>
                      </div>
                      <div className="summary-text" title={summary.summary}>
                        {summary.total_reports} reports
                      </div>
                    </div>
                  ) : (
                    <span className="no-data">No summary available</span>
                  )}
                </td>
                <td>
                  <div className="action-buttons">
                    <button
                      className="btn btn-sm"
                      onClick={() => onSelectPlan(testPlan)}
                      title="View Plan"
                    >
                      View
                    </button>
                    <button
                      className="btn btn-success btn-sm"
                      onClick={() => onRunPlan(testPlan.id)}
                      title="Run Plan"
                    >
                      Run
                    </button>
                    <button
                      className="btn btn-danger btn-sm"
                      onClick={() => onDeletePlan(testPlan.id)}
                      title="Delete Plan"
                    >
                      Del
                    </button>
                  </div>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
};

export default PlanList;