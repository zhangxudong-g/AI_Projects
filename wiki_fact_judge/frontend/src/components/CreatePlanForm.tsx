import React, { useState, useEffect, useMemo } from 'react';
import { caseApi, planApi } from '../api';
import { TestCase } from '../types';
import './CreatePlanForm.css';

interface CreatePlanFormProps {
  onPlanCreated: () => void;
}

const CreatePlanForm: React.FC<CreatePlanFormProps> = ({ onPlanCreated }) => {
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [allCases, setAllCases] = useState<TestCase[]>([]);
  const [selectedCaseIds, setSelectedCaseIds] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [creating, setCreating] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [selectedTag, setSelectedTag] = useState<string>('all');

  // 获取所有唯一的 tag 值
  const allTags = useMemo(() => {
    const tags = new Set<string>();
    allCases.forEach(c => {
      if (c.tag) {
        tags.add(c.tag);
      }
    });
    return Array.from(tags).sort();
  }, [allCases]);

  // 根据 tag 过滤 case
  const filteredCases = useMemo(() => {
    if (selectedTag === 'all') {
      return allCases;
    }
    return allCases.filter(c => c.tag === selectedTag);
  }, [allCases, selectedTag]);

  useEffect(() => {
    fetchAllCases();
  }, []);

  const fetchAllCases = async () => {
    try {
      setLoading(true);
      const response = await caseApi.getAllCases();
      setAllCases(response.data);
    } catch (err) {
      console.error('Failed to fetch cases:', err);
      setError('Failed to load cases');
    } finally {
      setLoading(false);
    }
  };

  const handleCaseSelection = (caseId: string, checked: boolean) => {
    if (checked) {
      setSelectedCaseIds([...selectedCaseIds, caseId]);
    } else {
      setSelectedCaseIds(selectedCaseIds.filter(id => id !== caseId));
    }
  };

  const handleSelectAllCases = (selectAll: boolean) => {
    if (selectAll) {
      setSelectedCaseIds(filteredCases.map(c => c.case_id));
    } else {
      setSelectedCaseIds([]);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!name.trim()) {
      setError('Name is required');
      return;
    }

    try {
      setCreating(true);

      // 调用后端API创建计划
      const planData = {
        name,
        description,
        case_ids: selectedCaseIds // 注意：后端字段名是 case_ids 而不是 caseIds
      };

      await planApi.createPlan(planData);

      alert('Plan created successfully!');
      setName('');
      setDescription('');
      setSelectedCaseIds([]);
      onPlanCreated();
    } catch (err: any) {
      console.error('Creation failed:', err);
      setError(err.message || 'Failed to create plan. Please try again.');
    } finally {
      setCreating(false);
    }
  };

  if (loading) {
    return <p>Loading cases...</p>;
  }

  return (
    <form onSubmit={handleSubmit} className="create-plan-form">
      {error && <div className="alert alert-danger">{error}</div>}
      
      <div className="form-group">
        <label htmlFor="planName" className="form-label">Plan Name *</label>
        <input
          type="text"
          id="planName"
          className="form-control"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Enter plan name"
          required
        />
      </div>
      
      <div className="form-group">
        <label htmlFor="planDescription" className="form-label">Description</label>
        <textarea
          id="planDescription"
          className="form-control"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder="Enter plan description"
          rows={3}
        />
      </div>
      
      <div className="form-group">
        <label className="form-label">Select Cases</label>
        <div className="case-selection-header">
          <div className="tag-filter-container">
            <label htmlFor="create-plan-tag-filter">Filter by Tag: </label>
            <select
              id="create-plan-tag-filter"
              value={selectedTag}
              onChange={(e) => setSelectedTag(e.target.value)}
              className="form-select"
              disabled={loading || creating}
            >
              <option value="all">全部</option>
              {allTags.map(tag => (
                <option key={tag} value={tag}>{tag}</option>
              ))}
            </select>
          </div>
          <div className="selection-actions">
            <button
              type="button"
              className="btn btn-sm btn-outline-primary"
              onClick={() => handleSelectAllCases(true)}
              disabled={loading || creating}
            >
              Select All
            </button>
            <button
              type="button"
              className="btn btn-sm btn-outline-secondary"
              onClick={() => handleSelectAllCases(false)}
              disabled={loading || creating}
            >
              Clear All
            </button>
          </div>
        </div>
        <div className="case-selection-list">
          {filteredCases.map((testCase) => (
            <div key={testCase.id} className="case-item">
              <label>
                <input
                  type="checkbox"
                  checked={selectedCaseIds.includes(testCase.case_id)}
                  onChange={(e) => handleCaseSelection(testCase.case_id, e.target.checked)}
                  disabled={loading || creating}
                />
                <span className="case-name">
                  {testCase.name} ({testCase.case_id})
                  {testCase.tag && <span className="case-tag"> - Tag: {testCase.tag}</span>}
                </span>
              </label>
            </div>
          ))}
        </div>
        {filteredCases.length === 0 && (
          <p className="no-cases-message">
            No cases found {selectedTag !== 'all' ? `with tag "${selectedTag}"` : ''}.
          </p>
        )}
      </div>
      
      <button 
        type="submit" 
        className="btn btn-primary"
        disabled={creating}
      >
        {creating ? 'Creating...' : 'Create Plan'}
      </button>
    </form>
  );
};

export default CreatePlanForm;