import React, { useState, useEffect } from 'react';
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
  const [selectedCaseIds, setSelectedCaseIds] = useState<string[]>(plan.case_ids || []);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchCases = async () => {
      try {
        const response = await caseApi.getAllCases();
        setAllCases(response.data);
      } catch (err) {
        console.error('Failed to fetch cases:', err);
        setError('Failed to load cases. Please try again later.');
      } finally {
        setLoading(false);
      }
    };

    fetchCases();
  }, []);

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
      setSelectedCaseIds(allCases.map(c => c.case_id));
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
            {allCases.map(testCase => (
              <div key={testCase.case_id} className="case-checkbox-item">
                <label>
                  <input
                    type="checkbox"
                    checked={selectedCaseIds.includes(testCase.case_id)}
                    onChange={(e) => handleCaseSelection(testCase.case_id, e.target.checked)}
                    disabled={loading}
                  />
                  <span className="case-name" title={testCase.name}>
                    {testCase.name} ({testCase.case_id})
                  </span>
                </label>
              </div>
            ))}
          </div>
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