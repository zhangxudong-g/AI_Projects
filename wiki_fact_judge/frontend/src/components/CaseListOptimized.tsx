import React, { useState } from 'react';
import { TestCase } from '../types';
import GenericTable, { TableColumn } from './GenericTableOptimized';

interface CaseListProps {
  cases: TestCase[];
  onSelectCase: (testCase: TestCase) => void;
  onRunCase: (caseId: string) => void;
  onDeleteCase: (caseId: string) => void;
  onBulkDelete: (caseIds: string[]) => void;
}

const CaseList: React.FC<CaseListProps> = ({ cases, onSelectCase, onRunCase, onDeleteCase, onBulkDelete }) => {
  const [selectedCases, setSelectedCases] = useState<TestCase[]>([]);
  const [deleting, setDeleting] = useState(false);

  const handleBulkDelete = () => {
    if (selectedCases.length > 0) {
      const caseIds = selectedCases.map(c => c.case_id);
      const caseNames = selectedCases.slice(0, 5).map(c => c.name).join(', ');
      const extraCount = selectedCases.length - 5;

      let confirmationMessage = `Are you sure you want to delete ${selectedCases.length} case(s)?`;
      if (selectedCases.length > 5) {
        confirmationMessage += `\n\nSelected cases: ${caseNames} and ${extraCount} more.`;
      } else {
        confirmationMessage += `\n\nSelected cases: ${caseNames}`;
      }

      if (window.confirm(confirmationMessage)) {
        setDeleting(true);
        onBulkDelete(caseIds);
      }
    } else {
      alert('Please select at least one case to delete.');
    }
  };

  const columns: TableColumn<TestCase>[] = [
    { key: 'case_id', label: 'ID', sortable: true },
    { key: 'name', label: 'Name', sortable: true },
    { 
      key: 'created_at', 
      label: 'Created At', 
      sortable: true,
      render: (value: TestCase[keyof TestCase], item: TestCase) => new Date(value as string).toLocaleString()
    }
  ];

  const actions = [
    { label: 'View', onClick: onSelectCase, className: 'btn-default' },
    { label: 'Run', onClick: (testCase: TestCase) => onRunCase(testCase.case_id), className: 'btn-success' },
    { label: 'Del', onClick: (testCase: TestCase) => onDeleteCase(testCase.case_id), className: 'btn-danger' }
  ];

  return (
    <div className="case-list">
      <div className="table-header">
        <div className="bulk-actions">
          <button
            className="btn btn-danger"
            onClick={handleBulkDelete}
            disabled={selectedCases.length === 0 || deleting}
          >
            {deleting ? 'Deleting...' : `Bulk Delete (${selectedCases.length})`}
          </button>
        </div>
      </div>

      <GenericTable<TestCase>
        data={cases}
        columns={columns}
        title=""
        onRowClick={onSelectCase}
        actions={actions}
        selectable={true}
        selectedItems={selectedCases}
        onSelectionChange={setSelectedCases}
        emptyMessage="No test cases found."
      />
    </div>
  );
};

export default CaseList;