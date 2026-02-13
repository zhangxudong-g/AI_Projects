import React, { useState } from 'react';
import { TestPlan } from '../types';
import PlanEditForm from './PlanEditForm';

interface PlanDetailProps {
  testPlan: TestPlan | null;
  onRunPlan: (planId: number) => void;
  onDeletePlan: (planId: number) => void;
  onPlanUpdated?: (updatedPlan: TestPlan) => void; // 新增更新回调
}

const PlanDetail: React.FC<PlanDetailProps> = ({ testPlan, onRunPlan, onDeletePlan, onPlanUpdated }) => {
  const [isEditing, setIsEditing] = useState(false);

  if (!testPlan) {
    return <div className="container"><p>Select a plan to view details</p></div>;
  }

  if (isEditing) {
    return (
      <div className="container">
        <div className="card">
          <PlanEditForm
            plan={testPlan}
            onSave={(updatedPlan) => {
              setIsEditing(false);
              if (onPlanUpdated) {
                onPlanUpdated(updatedPlan);
              }
            }}
            onCancel={() => setIsEditing(false)}
          />
        </div>
      </div>
    );
  }

  return (
    <div className="container">
      <div className="card">
        <div className="detail-header">
          <h3>Plan Details: {testPlan.name}</h3>
          <button
            className="btn btn-primary"
            onClick={() => setIsEditing(true)}
          >
            Edit Plan
          </button>
        </div>

        <div className="plan-info">
          <p><strong>ID:</strong> {testPlan.id}</p>
          <p><strong>Name:</strong> {testPlan.name}</p>
          <p><strong>Description:</strong> {testPlan.description || 'No description'}</p>
          <p><strong>Created:</strong> {new Date(testPlan.created_at).toLocaleString()}</p>
        </div>

        <div className="actions">
          <button
            className="btn btn-success"
            onClick={() => onRunPlan(testPlan.id)}
          >
            Run Plan
          </button>

          <button
            className="btn btn-danger"
            onClick={() => onDeletePlan(testPlan.id)}
          >
            Delete Plan
          </button>
        </div>
      </div>
    </div>
  );
};

export default PlanDetail;