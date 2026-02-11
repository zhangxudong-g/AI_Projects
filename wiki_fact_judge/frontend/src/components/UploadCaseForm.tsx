import React, { useState } from 'react';
import { caseApi } from '../api';

interface UploadCaseFormProps {
  onUploadSuccess: () => void;
}

const UploadCaseForm: React.FC<UploadCaseFormProps> = ({ onUploadSuccess }) => {
  const [name, setName] = useState('');
  const [sourceCodeFile, setSourceCodeFile] = useState<File | null>(null);
  const [wikiFile, setWikiFile] = useState<File | null>(null);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!name.trim()) {
      setError('Name is required');
      return;
    }

    const formData = new FormData();
    formData.append('name', name);

    if (sourceCodeFile) {
      formData.append('source_code', sourceCodeFile);
    }

    if (wikiFile) {
      formData.append('wiki', wikiFile);
    }

    try {
      setUploading(true);

      // 调用后端API上传案例
      const response = await caseApi.createCase(formData);

      if (response && response.data) {
        alert('Case uploaded successfully!');
        setName('');
        setSourceCodeFile(null);
        setWikiFile(null);
        onUploadSuccess();
      } else {
        throw new Error('Invalid response from server');
      }
    } catch (err: any) {
      console.error('Upload failed:', err);
      setError(err.message || 'Failed to upload case. Please try again.');
    } finally {
      setUploading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="upload-case-form">
      {error && <div className="alert alert-danger">{error}</div>}

      <div className="form-group">
        <label htmlFor="name" className="form-label">Case Name *</label>
        <input
          type="text"
          id="name"
          className="form-control"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Enter case name"
          required
        />
      </div>

      <div className="form-group">
        <label htmlFor="sourceCode" className="form-label">Source Code File *</label>
        <input
          type="file"
          id="sourceCode"
          className="form-control"
          onChange={(e) => setSourceCodeFile(e.target.files?.[0] || null)}
          required
        />
      </div>

      <div className="form-group">
        <label htmlFor="wiki" className="form-label">Wiki File *</label>
        <input
          type="file"
          id="wiki"
          className="form-control"
          onChange={(e) => setWikiFile(e.target.files?.[0] || null)}
          required
        />
      </div>

      <button
        type="submit"
        className="btn btn-primary"
        disabled={uploading}
      >
        {uploading ? 'Uploading...' : 'Upload Case'}
      </button>
    </form>
  );
};

export default UploadCaseForm;