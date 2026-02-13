import React, { useState } from 'react';

interface FormField {
  name: string;
  label: string;
  type: 'text' | 'textarea' | 'file' | 'select';
  options?: { value: string; label: string }[];
  required?: boolean;
  placeholder?: string;
}

interface GenericFormProps {
  fields: FormField[];
  onSubmit: (formData: Record<string, any>) => void;
  submitLabel: string;
  title?: string;
  initialValues?: Record<string, any>;
  loading?: boolean;
}

const GenericForm: React.FC<GenericFormProps> = ({
  fields,
  onSubmit,
  submitLabel,
  title,
  initialValues = {},
  loading = false
}) => {
  const [formData, setFormData] = useState<Record<string, any>>(initialValues);
  const [errors, setErrors] = useState<Record<string, string>>({});

  const handleChange = (name: string, value: any) => {
    setFormData(prev => ({
      ...prev,
      [name]: value
    }));

    // Clear error when user starts typing
    if (errors[name]) {
      setErrors(prev => {
        const newErrors = { ...prev };
        delete newErrors[name];
        return newErrors;
      });
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    // Validate required fields
    const newErrors: Record<string, string> = {};
    fields.forEach(field => {
      if (field.required && !formData[field.name]) {
        newErrors[field.name] = `${field.label} is required`;
      }
    });

    if (Object.keys(newErrors).length > 0) {
      setErrors(newErrors);
      return;
    }

    onSubmit(formData);
  };

  const renderField = (field: FormField) => {
    switch (field.type) {
      case 'text':
        return (
          <input
            type="text"
            id={field.name}
            value={formData[field.name] || ''}
            onChange={(e) => handleChange(field.name, e.target.value)}
            placeholder={field.placeholder}
            className={`form-control ${errors[field.name] ? 'is-invalid' : ''}`}
          />
        );
      case 'textarea':
        return (
          <textarea
            id={field.name}
            value={formData[field.name] || ''}
            onChange={(e) => handleChange(field.name, e.target.value)}
            placeholder={field.placeholder}
            rows={4}
            className={`form-control ${errors[field.name] ? 'is-invalid' : ''}`}
          />
        );
      case 'file':
        return (
          <input
            type="file"
            id={field.name}
            onChange={(e) => handleChange(field.name, e.target.files?.[0] || null)}
            className={`form-control ${errors[field.name] ? 'is-invalid' : ''}`}
          />
        );
      case 'select':
        return (
          <select
            id={field.name}
            value={formData[field.name] || ''}
            onChange={(e) => handleChange(field.name, e.target.value)}
            className={`form-select ${errors[field.name] ? 'is-invalid' : ''}`}
          >
            <option value="">Select {field.label}</option>
            {field.options?.map(option => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        );
      default:
        return null;
    }
  };

  return (
    <div className="generic-form">
      {title && <h3>{title}</h3>}
      <form onSubmit={handleSubmit}>
        {fields.map(field => (
          <div key={field.name} className="mb-3">
            <label htmlFor={field.name} className="form-label">
              {field.label} {field.required && <span className="text-danger">*</span>}
            </label>
            {renderField(field)}
            {errors[field.name] && (
              <div className="invalid-feedback">{errors[field.name]}</div>
            )}
          </div>
        ))}
        <button 
          type="submit" 
          className="btn btn-primary" 
          disabled={loading}
        >
          {loading ? 'Submitting...' : submitLabel}
        </button>
      </form>
    </div>
  );
};

export default GenericForm;