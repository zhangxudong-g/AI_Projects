import React from 'react';
import { TestCase } from '../types';

interface CaseDetailProps {
  testCase: TestCase | null;
  onRunCase: (caseId: string) => void;
  onDeleteCase: (caseId: string) => void;
}

const CaseDetail: React.FC<CaseDetailProps> = ({ testCase, onRunCase, onDeleteCase }) => {
  if (!testCase) {
    return <div className="container"><p>Select a case to view details</p></div>;
  }

  return (
    <div className="container">
      <div className="card">
        <h3>Case Details: {testCase.name}</h3>
        
        <div className="case-info">
          <p><strong>ID:</strong> {testCase.case_id}</p>
          <p><strong>Name:</strong> {testCase.name}</p>
          <p><strong>Created:</strong> {new Date(testCase.created_at).toLocaleString()}</p>
          <p><strong>Last Updated:</strong> {new Date(testCase.updated_at).toLocaleString()}</p>
          
          {testCase.source_code_path && (
            <p><strong>Source Code:</strong> {testCase.source_code_path}</p>
          )}
          
          {testCase.wiki_path && (
            <p><strong>Wiki File:</strong> {testCase.wiki_path}</p>
          )}
          
          {testCase.yaml_path && (
            <p><strong>YAML Config:</strong> {testCase.yaml_path}</p>
          )}
        </div>
        
        <div className="actions">
          <button 
            className="btn btn-success"
            onClick={() => onRunCase(testCase.case_id)}
          >
            Run Case
          </button>
          
          <button 
            className="btn btn-danger"
            onClick={() => onDeleteCase(testCase.case_id)}
          >
            Delete Case
          </button>
        </div>
      </div>
    </div>
  );
};

export default CaseDetail;