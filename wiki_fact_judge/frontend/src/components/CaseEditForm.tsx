import React, { useState } from 'react';
import { TestCase } from '../types';
import { caseApi } from '../api';

interface CaseEditFormProps {
  testCase: TestCase;
  onSave: (updatedCase: TestCase) => void;
  onCancel: () => void;
}

// 文件验证函数
const validateFile = (file: File): boolean => {
  // 检查文件大小（限制为10MB）
  const maxSize = 10 * 1024 * 1024; // 10MB
  if (file.size > maxSize) {
    throw new Error('File size exceeds 10MB limit');
  }
  
  // 验证文件扩展名
  const allowedExtensions = [
    '.txt', '.js', '.ts', '.jsx', '.tsx', '.py', '.java', 
    '.cpp', '.c', '.h', '.cs', '.go', '.rs', '.rb', '.php', 
    '.html', '.css', '.json', '.yaml', '.yml', '.md'
  ];
  const fileExtension = '.' + file.name.split('.').pop()?.toLowerCase();
  if (!allowedExtensions.includes(fileExtension)) {
    throw new Error('Invalid file type. Allowed types: ' + allowedExtensions.join(', '));
  }
  
  return true;
};

const CaseEditForm: React.FC<CaseEditFormProps> = ({ testCase, onSave, onCancel }) => {
  const [formData, setFormData] = useState({
    name: testCase.name,
    source_code_path: testCase.source_code_path || '',
    wiki_path: testCase.wiki_path || '',
    yaml_path: testCase.yaml_path || ''
  });
  const [files, setFiles] = useState({
    source_code: null as File | null,
    wiki: null as File | null,
    yaml_file: null as File | null
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value
    }));
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>, fileType: keyof typeof files) => {
    if (e.target.files && e.target.files[0]) {
      const file = e.target.files[0];
      try {
        validateFile(file);
        setFiles(prev => ({
          ...prev,
          [fileType]: file
        }));
        setError(null); // 清除之前的错误
      } catch (err: any) {
        setError(err.message);
        // 清除已选的无效文件
        setFiles(prev => ({
          ...prev,
          [fileType]: null
        }));
      }
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      // 使用FormData来处理文件上传
      const formDataToSend = new FormData();
      formDataToSend.append('name', formData.name);
      
      // 添加文件（如果有选择的话）
      if (files.source_code) {
        formDataToSend.append('source_code', files.source_code);
      }
      if (files.wiki) {
        formDataToSend.append('wiki', files.wiki);
      }
      if (files.yaml_file) {
        formDataToSend.append('yaml_file', files.yaml_file);
      }

      // 如果没有选择文件，使用文本路径字段
      if (!files.source_code && formData.source_code_path) {
        formDataToSend.append('source_code_path', formData.source_code_path);
      }
      if (!files.wiki && formData.wiki_path) {
        formDataToSend.append('wiki_path', formData.wiki_path);
      }
      if (!files.yaml_file && formData.yaml_path) {
        formDataToSend.append('yaml_path', formData.yaml_path);
      }

      const response = await caseApi.updateCaseFiles(testCase.case_id, formDataToSend);
      onSave(response.data);
    } catch (err: any) {
      console.error('Failed to update case:', err);
      let errorMessage = 'Failed to update case. Please try again.';
      if (err.response?.data?.detail) {
        errorMessage = err.response.data.detail;
      } else if (err.message) {
        errorMessage = err.message;
      }
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="case-edit-form">
      <h3>Edit Case</h3>
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
          <label htmlFor="source_code">Upload Source Code</label>
          <input
            type="file"
            id="source_code"
            name="source_code"
            accept=".txt,.js,.ts,.jsx,.tsx,.py,.java,.cpp,.c,.h,.cs,.go,.rs,.rb,.php,.html,.css,.json,.yaml,.yml"
            onChange={(e) => handleFileChange(e, 'source_code')}
            disabled={loading}
          />
          <small>Current path: {formData.source_code_path || 'Not uploaded'}</small>
        </div>
        
        <div className="form-group">
          <label htmlFor="wiki">Upload Wiki File</label>
          <input
            type="file"
            id="wiki"
            name="wiki"
            accept=".md,.txt,.html"
            onChange={(e) => handleFileChange(e, 'wiki')}
            disabled={loading}
          />
          <small>Current path: {formData.wiki_path || 'Not uploaded'}</small>
        </div>
        
        <div className="form-group">
          <label htmlFor="yaml_file">Upload YAML Config</label>
          <input
            type="file"
            id="yaml_file"
            name="yaml_file"
            accept=".yaml,.yml"
            onChange={(e) => handleFileChange(e, 'yaml_file')}
            disabled={loading}
          />
          <small>Current path: {formData.yaml_path || 'Not uploaded'}</small>
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

export default CaseEditForm;