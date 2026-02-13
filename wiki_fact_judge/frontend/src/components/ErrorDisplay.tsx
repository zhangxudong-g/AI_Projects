import React from 'react';
import './ErrorDisplay.css';

interface ErrorDisplayProps {
  message: string;
  onDismiss?: () => void;
}

const ErrorDisplay: React.FC<ErrorDisplayProps> = ({ message, onDismiss }) => {
  return (
    <div className="error-display">
      <div className="error-content">
        <span className="error-message">{message}</span>
        {onDismiss && (
          <button className="error-dismiss-btn" onClick={onDismiss}>
            ×
          </button>
        )}
      </div>
    </div>
  );
};

export default ErrorDisplay;