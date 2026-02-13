import React, { useState } from 'react';
import { TestCase } from '../types';
import CaseEditForm from './CaseEditForm';

interface CaseDetailProps {
  testCase: TestCase | null;
  onRunCase: (caseId: string) => void;
  onDeleteCase: (caseId: string) => void;
  onCaseUpdated?: (updatedCase: TestCase) => void; // 新增更新回调
}

const CaseDetail: React.FC<CaseDetailProps> = ({ testCase, onRunCase, onDeleteCase, onCaseUpdated }) => {
  const [isEditing, setIsEditing] = useState(false);

  if (!testCase) {
    return <div className="container"><p>Select a case to view details</p></div>;
  }

  if (isEditing) {
    return (
      <div className="container">
        <div className="card">
          <CaseEditForm
            testCase={testCase}
            onSave={(updatedCase) => {
              setIsEditing(false);
              if (onCaseUpdated) {
                onCaseUpdated(updatedCase);
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
          <h3>Case Details: {testCase.name}</h3>
          <button
            className="btn btn-primary"
            onClick={() => setIsEditing(true)}
          >
            Edit Case
          </button>
        </div>

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