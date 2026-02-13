import React, { useState } from 'react';
import './ScheduledExecution.css';

interface ScheduledExecutionProps {
  planId: number;
  planName: string;
}

interface ScheduleConfig {
  enabled: boolean;
  cronExpression: string;
  nextRunTime?: string;
}

const ScheduledExecution: React.FC<ScheduledExecutionProps> = ({ planId, planName }) => {
  const [schedule, setSchedule] = useState<ScheduleConfig>({
    enabled: false,
    cronExpression: '0 9 * * *', // 默认每天上午9点执行
  });
  const [isEditing, setIsEditing] = useState(false);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  const handleEnableToggle = () => {
    setSchedule(prev => ({
      ...prev,
      enabled: !prev.enabled
    }));
  };

  const handleCronChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setSchedule(prev => ({
      ...prev,
      cronExpression: e.target.value
    }));
  };

  const handleSave = async () => {
    setLoading(true);
    setError('');
    setMessage('');
    
    try {
      // 这里应该是调用后端API来设置定时任务
      // 由于后端可能还没有实现定时任务功能，我们暂时模拟一个API调用
      console.log(`Setting schedule for plan ${planId}:`, schedule);
      
      // 模拟API调用
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      setMessage(`Schedule ${schedule.enabled ? 'enabled' : 'disabled'} for plan "${planName}"`);
      setIsEditing(false);
    } catch (err) {
      setError('Failed to save schedule. Please try again.');
      console.error('Error saving schedule:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleEdit = () => {
    setIsEditing(true);
  };

  const handleCancel = () => {
    // 重置为之前的状态
    setIsEditing(false);
  };

  const commonCronExpressions = [
    { label: 'Every hour', value: '0 * * * *' },
    { label: 'Daily at 9 AM', value: '0 9 * * *' },
    { label: 'Weekly on Sunday at midnight', value: '0 0 * * 0' },
    { label: 'Monthly on 1st at midnight', value: '0 0 1 * *' },
  ];

  return (
    <div className="scheduled-execution">
      <div className="schedule-header">
        <h4>Scheduled Execution for "{planName}"</h4>
        <div className="toggle-switch">
          <label className="switch">
            <input
              type="checkbox"
              checked={schedule.enabled}
              onChange={handleEnableToggle}
              disabled={isEditing}
            />
            <span className="slider round"></span>
          </label>
          <span className="toggle-label">
            {schedule.enabled ? 'Enabled' : 'Disabled'}
          </span>
        </div>
      </div>

      <div className="schedule-config">
        {isEditing ? (
          <div className="edit-mode">
            <div className="form-group">
              <label htmlFor="cronExpression">Cron Expression:</label>
              <input
                id="cronExpression"
                type="text"
                value={schedule.cronExpression}
                onChange={handleCronChange}
                placeholder="Enter cron expression (e.g., 0 9 * * *)"
              />
              <small className="help-text">
                Cron format: minute hour day month weekday (e.g., "0 9 * * *" for daily at 9 AM)
              </small>
            </div>

            <div className="common-schedules">
              <h5>Common Schedules:</h5>
              <div className="cron-options">
                {commonCronExpressions.map((option, index) => (
                  <button
                    key={index}
                    type="button"
                    className={`cron-option ${schedule.cronExpression === option.value ? 'active' : ''}`}
                    onClick={() => setSchedule(prev => ({ ...prev, cronExpression: option.value }))}
                  >
                    {option.label}
                  </button>
                ))}
              </div>
            </div>

            <div className="action-buttons">
              <button
                className="btn btn-primary"
                onClick={handleSave}
                disabled={loading}
              >
                {loading ? 'Saving...' : 'Save'}
              </button>
              <button
                className="btn btn-secondary"
                onClick={handleCancel}
                disabled={loading}
              >
                Cancel
              </button>
            </div>
          </div>
        ) : (
          <div className="view-mode">
            <div className="schedule-info">
              <p><strong>Cron Expression:</strong> {schedule.cronExpression}</p>
              <p><strong>Status:</strong> {schedule.enabled ? 'Active' : 'Inactive'}</p>
              {schedule.nextRunTime && (
                <p><strong>Next Run:</strong> {new Date(schedule.nextRunTime).toLocaleString()}</p>
              )}
            </div>
            <button
              className="btn btn-secondary"
              onClick={handleEdit}
              disabled={!schedule.enabled}
            >
              Edit Schedule
            </button>
          </div>
        )}
      </div>

      {message && (
        <div className="message success">
          {message}
        </div>
      )}

      {error && (
        <div className="message error">
          {error}
        </div>
      )}
    </div>
  );
};

export default ScheduledExecution;