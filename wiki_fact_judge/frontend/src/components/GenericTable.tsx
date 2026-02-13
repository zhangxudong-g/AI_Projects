import React from 'react';
import './GenericTable.css';

interface KeyValue {
  key: string;
  value: any;
}

interface GenericTableProps {
  data: Record<string, any> | KeyValue[];
  title?: string;
  className?: string;
}

const GenericTable: React.FC<GenericTableProps> = ({ data, title, className = '' }) => {
  let rows: KeyValue[] = [];

  // 如果数据是对象，则转换为键值对数组
  if (data && typeof data === 'object' && !Array.isArray(data)) {
    rows = Object.entries(data).map(([key, value]) => ({
      key,
      value: value !== null && value !== undefined ? value : 'N/A'
    }));
  } else if (Array.isArray(data)) {
    // 如果数据已经是KeyValue数组
    rows = data;
  }

  // 递归渲染值，处理嵌套对象和数组
  const renderValue = (value: any): React.ReactNode => {
    if (value === null || value === undefined) {
      return 'N/A';
    }
    
    if (typeof value === 'object') {
      if (Array.isArray(value)) {
        // 处理数组
        return (
          <ul style={{ margin: 0, paddingLeft: '20px' }}>
            {value.map((item, index) => (
              <li key={index}>{renderValue(item)}</li>
            ))}
          </ul>
        );
      } else {
        // 处理嵌套对象 - 创建嵌套表格
        return <GenericTable data={value} />;
      }
    }
    
    // 处理基本类型
    return String(value);
  };

  return (
    <div className={`generic-table-container ${className}`}>
      {title && <h4>{title}</h4>}
      <table className="table">
        <thead>
          <tr>
            <th className="col-field">Field</th>
            <th className="col-value">Value</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row, index) => (
            <tr key={index}>
              <td><strong>{row.key}:</strong></td>
              <td>{renderValue(row.value)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default GenericTable;