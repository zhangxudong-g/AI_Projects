import React, { useState, useEffect } from 'react';
import { caseApi, planApi } from '../api';
import { TestCase } from '../types';

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
        <div className="case-selection-list">
          {allCases.map((testCase) => (
            <div key={testCase.id} className="case-item">
              <label>
                <input
                  type="checkbox"
                  checked={selectedCaseIds.includes(testCase.case_id)}
                  onChange={(e) => handleCaseSelection(testCase.case_id, e.target.checked)}
                />
                <span style={{ marginLeft: '8px' }}>{testCase.name} ({testCase.case_id})</span>
              </label>
            </div>
          ))}
        </div>
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