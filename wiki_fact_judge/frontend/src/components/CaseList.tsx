import React from 'react';
import { TestCase } from '../types';

interface CaseListProps {
  cases: TestCase[];
  onSelectCase: (testCase: TestCase) => void;
  onRunCase: (caseId: string) => void;
  onDeleteCase: (caseId: string) => void;
}

const CaseList: React.FC<CaseListProps> = ({ cases, onSelectCase, onRunCase, onDeleteCase }) => {
  if (cases.length === 0) {
    return <p>No test cases found.</p>;
  }

  return (
    <div className="case-list">
      <table className="table">
        <thead>
          <tr>
            <th>ID</th>
            <th>Name</th>
            <th>Created At</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {cases.map((testCase) => (
            <tr key={testCase.id}>
              <td>{testCase.case_id}</td>
              <td>{testCase.name}</td>
              <td>{new Date(testCase.created_at).toLocaleString()}</td>
              <td>
                <button 
                  className="btn"
                  onClick={() => onSelectCase(testCase)}
                >
                  View
                </button>
                <button 
                  className="btn btn-success"
                  onClick={() => onRunCase(testCase.case_id)}
                >
                  Run
                </button>
                <button 
                  className="btn btn-danger"
                  onClick={() => onDeleteCase(testCase.case_id)}
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

export default CaseList;