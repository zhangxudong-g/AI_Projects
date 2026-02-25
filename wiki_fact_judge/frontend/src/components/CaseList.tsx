import React, { useState, useMemo } from 'react';
import { TestCase } from '../types';

interface CaseListProps {
  cases: TestCase[];
  onSelectCase: (testCase: TestCase) => void;
  onRunCase: (caseId: string) => void;
  onDeleteCase: (caseId: string) => void;
  onBulkDelete: (caseIds: string[]) => void;
}

const CaseList: React.FC<CaseListProps> = ({ cases, onSelectCase, onRunCase, onDeleteCase, onBulkDelete }) => {
  const [selectedCases, setSelectedCases] = useState<string[]>([]);
  const [selectedTag, setSelectedTag] = useState<string>('all');
  const [deleting, setDeleting] = useState(false);

  // 获取所有唯一的 tag 值
  const allTags = useMemo(() => {
    const tags = new Set<string>();
    cases.forEach(c => {
      if (c.tag) {
        tags.add(c.tag);
      }
    });
    return Array.from(tags).sort();
  }, [cases]);

  // 根据 tag 过滤 case
  const filteredCases = useMemo(() => {
    if (selectedTag === 'all') {
      return cases;
    }
    return cases.filter(c => c.tag === selectedTag);
  }, [cases, selectedTag]);


  if (cases.length === 0) {
    return <p>No test cases found.</p>;
  }

  const handleSelectAll = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.checked) {
      setSelectedCases(filteredCases.map(caseItem => caseItem.case_id));
    } else {
      setSelectedCases([]);
    }
  };

  const handleSingleSelect = (caseId: string, checked: boolean) => {
    if (checked) {
      setSelectedCases(prev => [...prev, caseId]);
    } else {
      setSelectedCases(prev => prev.filter(id => id !== caseId));
    }
  };

  const handleBulkDelete = () => {
    if (selectedCases.length > 0) {
      const caseNames = selectedCases.slice(0, 5).map(id =>
        cases.find(c => c.case_id === id)?.name || id
      ).join(', ');
      const extraCount = selectedCases.length - 5;

      let confirmationMessage = `Are you sure you want to delete ${selectedCases.length} case(s)?`;
      if (selectedCases.length > 5) {
        confirmationMessage += `\n\nSelected cases: ${caseNames} and ${extraCount} more.`;
      } else {
        confirmationMessage += `\n\nSelected cases: ${caseNames}`;
      }

      if (window.confirm(confirmationMessage)) {
        setDeleting(true);
        onBulkDelete(selectedCases);
      }
    } else {
      alert('Please select at least one case to delete.');
    }
  };

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
          
          {/* Tag 过滤器 */}
          <div className="tag-filter">
            <label htmlFor="tag-filter">Tag: </label>
            <select
              id="tag-filter"
              value={selectedTag}
              onChange={(e) => setSelectedTag(e.target.value)}
              className="form-select"
            >
              <option value="all">全部</option>
              {allTags.map(tag => (
                <option key={tag} value={tag}>{tag}</option>
              ))}
            </select>
          </div>
        </div>
      </div>

      <table className="table">
        <thead>
          <tr>
            <th className="col-checkbox">
              <input
                type="checkbox"
                onChange={handleSelectAll}
                checked={selectedCases.length === filteredCases.length && filteredCases.length > 0}
              />
            </th>
            <th className="col-id">ID</th>
            <th className="col-name">Name</th>
            <th className="col-tag">Tag</th>
            <th className="col-created">Created At</th>
            <th className="col-actions">Actions</th>
          </tr>
        </thead>
        <tbody>
          {filteredCases.map((testCase) => (
            <tr key={testCase.id}>
              <td>
                <input
                  type="checkbox"
                  checked={selectedCases.includes(testCase.case_id)}
                  onChange={(e) => handleSingleSelect(testCase.case_id, e.target.checked)}
                />
              </td>
              <td>{testCase.case_id}</td>
              <td title={testCase.name}>{testCase.name}</td>
              <td>{testCase.tag || '-'}</td>
              <td>{new Date(testCase.created_at).toLocaleString()}</td>
              <td>
                <div className="action-buttons">
                  <button
                    className="btn btn-sm"
                    onClick={() => onSelectCase(testCase)}
                    title="View Case"
                  >
                    View
                  </button>
                  <button
                    className="btn btn-success btn-sm"
                    onClick={() => onRunCase(testCase.case_id)}
                    title="Run Case"
                  >
                    Run
                  </button>
                  <button
                    className="btn btn-danger btn-sm"
                    onClick={() => onDeleteCase(testCase.case_id)}
                    title="Delete Case"
                  >
                    Del
                  </button>
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default CaseList;