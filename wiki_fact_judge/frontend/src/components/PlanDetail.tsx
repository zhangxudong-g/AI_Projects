import React from 'react';
import { TestPlan } from '../types';

interface PlanDetailProps {
  testPlan: TestPlan | null;
  onRunPlan: (planId: number) => void;
  onDeletePlan: (planId: number) => void;
}

const PlanDetail: React.FC<PlanDetailProps> = ({ testPlan, onRunPlan, onDeletePlan }) => {
  if (!testPlan) {
    return <div className="container"><p>Select a plan to view details</p></div>;
  }

  return (
    <div className="container">
      <div className="card">
        <h3>Plan Details: {testPlan.name}</h3>
        
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