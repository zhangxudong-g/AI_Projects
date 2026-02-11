import React from 'react';
import { TestPlan } from '../types';

interface PlanListProps {
  plans: TestPlan[];
  onSelectPlan: (testPlan: TestPlan) => void;
  onRunPlan: (planId: number) => void;
  onDeletePlan: (planId: number) => void;
}

const PlanList: React.FC<PlanListProps> = ({ plans, onSelectPlan, onRunPlan, onDeletePlan }) => {
  if (plans.length === 0) {
    return <p>No test plans found.</p>;
  }

  return (
    <div className="plan-list">
      <table className="table">
        <thead>
          <tr>
            <th>ID</th>
            <th>Name</th>
            <th>Description</th>
            <th>Created At</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {plans.map((testPlan) => (
            <tr key={testPlan.id}>
              <td>{testPlan.id}</td>
              <td>{testPlan.name}</td>
              <td>{testPlan.description || '-'}</td>
              <td>{new Date(testPlan.created_at).toLocaleString()}</td>
              <td>
                <button 
                  className="btn"
                  onClick={() => onSelectPlan(testPlan)}
                >
                  View
                </button>
                <button 
                  className="btn btn-success"
                  onClick={() => onRunPlan(testPlan.id)}
                >
                  Run
                </button>
                <button 
                  className="btn btn-danger"
                  onClick={() => onDeletePlan(testPlan.id)}
                >
                  Delete
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default PlanList;