import React, { useState, useEffect, useMemo } from 'react';
import { TestPlan, TestCase } from '../types';
import { planApi, caseApi } from '../api';
import './PlanEditForm.css';

interface PlanEditFormProps {
  plan: TestPlan;
  onSave: (updatedPlan: TestPlan) => void;
  onCancel: () => void;
}

const PlanEditForm: React.FC<PlanEditFormProps> = ({ plan, onSave, onCancel }) => {
  const [formData, setFormData] = useState({
    name: plan.name,
    description: plan.description || ''
  });
  const [allCases, setAllCases] = useState<TestCase[]>([]);
  const [selectedCaseIds, setSelectedCaseIds] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
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

  // 调试：打印 plan 对象
  useEffect(() => {
    console.log('PlanEditForm - plan object:', plan);
    console.log('PlanEditForm - plan.case_ids:', plan.case_ids);
    console.log('PlanEditForm - plan.case_ids type:', Array.isArray(plan.case_ids) ? 'array' : typeof plan.case_ids);
  }, [plan]);

  useEffect(() => {
    const fetchCases = async () => {
      try {
        const response = await caseApi.getAllCases();
        const cases = response.data;
        setAllCases(cases);

        // allCases 加载完成后，根据 plan.case_ids 设置选中的 case
        // 确保转换为字符串类型以匹配 testCase.case_id
        if (plan.case_ids && plan.case_ids.length > 0) {
          const caseIds = plan.case_ids.map(id => String(id));
          console.log('Plan edit: Setting selected case IDs:', caseIds);
          setSelectedCaseIds(caseIds);
        }
      } catch (err) {
        console.error('Failed to fetch cases:', err);
        setError('Failed to load cases. Please try again later.');
      } finally {
        setLoading(false);
      }
    };

    fetchCases();
  }, [plan.case_ids]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value
    }));
  };

  const handleCaseSelection = (caseId: string, isSelected: boolean) => {
    if (isSelected) {
      setSelectedCaseIds(prev => [...prev, caseId]);
    } else {
      setSelectedCaseIds(prev => prev.filter(id => id !== caseId));
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
    setLoading(true);
    setError(null);

    try {
      // 包含案例ID的更新数据
      const updateData = {
        ...formData,
        case_ids: selectedCaseIds
      };

      const response = await planApi.updatePlan(plan.id, updateData);
      onSave(response.data);
    } catch (err) {
      console.error('Failed to update plan:', err);
      setError('Failed to update plan. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  if (loading && allCases.length === 0) {
    return (
      <div className="plan-edit-form">
        <h3>Edit Plan</h3>
        <p>Loading cases...</p>
      </div>
    );
  }

  return (
    <div className="plan-edit-form">
      <h3>Edit Plan</h3>
      {error && <div className="error-message">{error}</div>}

      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <label htmlFor="name">Name *</label>
          <input
            type="text"
            id="name"
            name="name"
            value={formData.name}
            onChange={handleChange}
            required
            disabled={loading}
          />
        </div>

        <div className="form-group">
          <label htmlFor="description">Description</label>
          <textarea
            id="description"
            name="description"
            value={formData.description}
            onChange={handleChange}
            rows={4}
            disabled={loading}
          />
        </div>

        <div className="form-group">
          <div className="case-selection-header">
            <label>Select Test Cases for this Plan:</label>
            <div className="tag-filter-container">
              <label htmlFor="case-tag-filter">Filter by Tag: </label>
              <select
                id="case-tag-filter"
                value={selectedTag}
                onChange={(e) => setSelectedTag(e.target.value)}
                className="form-select"
                disabled={loading}
              >
                <option value="all">全部</option>
                {allTags.map(tag => (
                  <option key={tag} value={tag}>{tag}</option>
                ))}
              </select>
            </div>
            <button
              type="button"
              className="btn btn-sm btn-outline-primary"
              onClick={() => handleSelectAllCases(true)}
              disabled={loading}
            >
              Select All
            </button>
            <button
              type="button"
              className="btn btn-sm btn-outline-secondary"
              onClick={() => handleSelectAllCases(false)}
              disabled={loading}
            >
              Clear All
            </button>
          </div>
          <div className="case-selection-list">
            {filteredCases.map(testCase => (
              <div key={testCase.case_id} className="case-checkbox-item">
                <label>
                  <input
                    type="checkbox"
                    checked={selectedCaseIds.includes(String(testCase.case_id))}
                    onChange={(e) => handleCaseSelection(String(testCase.case_id), e.target.checked)}
                    disabled={loading}
                  />
                  <span className="case-name" title={testCase.name}>
                    {testCase.name} ({testCase.case_id})
                    {testCase.tag && <span className="case-tag"> - Tag: {testCase.tag}</span>}
                  </span>
                </label>
              </div>
            ))}
          </div>
          {filteredCases.length === 0 && (
            <p className="no-cases-message">No cases found {selectedTag !== 'all' ? `with tag "${selectedTag}"` : ''}.</p>
          )}
        </div>

        <div className="form-actions">
          <button
            type="submit"
            className="btn btn-primary"
            disabled={loading}
          >
            {loading ? 'Saving...' : 'Save Changes'}
          </button>

          <button
            type="button"
            className="btn btn-secondary"
            onClick={onCancel}
            disabled={loading}
          >
            Cancel
          </button>
        </div>
      </form>
    </div>
  );
};

export default PlanEditForm;