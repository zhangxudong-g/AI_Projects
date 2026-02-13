import React, { useState } from 'react';

// 定义更具体的类型而不是使用 any
type JsonValue = string | number | boolean | null | JsonObject | JsonArray;
interface JsonObject {
  [key: string]: JsonValue;
}
type JsonArray = JsonValue[];

interface JsonDisplayProps {
  data: JsonValue;
  title?: string;
}

// 安全地转义HTML内容以防止XSS
const escapeHtml = (unsafe: any): string => {
  if (typeof unsafe !== 'string') {
    // 如果不是字符串，转换为字符串后再进行转义
    unsafe = String(unsafe);
  }
  return unsafe
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
};

const JsonDisplay: React.FC<JsonDisplayProps> = ({ data, title }) => {
  const [expandedPaths, setExpandedPaths] = useState<Set<string>>(new Set());

  // 递归渲染JSON对象
  const renderJsonValue = (value: JsonValue, path: string = '') => {
    if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean' || value === null) {
      // 基础类型直接显示
      let displayValue = String(value);
      
      // 对字符串值进行HTML转义以防止XSS
      if (typeof value === 'string') {
        displayValue = escapeHtml(displayValue);
      }
      
      if (typeof value === 'string' && value.length > 100) {
        // 如果字符串太长，截断并提供展开选项
        return <TruncatedText text={displayValue} />;
      }
      return <span className="json-value">{displayValue}</span>;
    } else if (Array.isArray(value)) {
      // 数组类型
      const isExpanded = expandedPaths.has(path);
      const toggleExpand = () => {
        setExpandedPaths(prev => {
          const newSet = new Set(prev);
          if (newSet.has(path)) {
            newSet.delete(path);
          } else {
            newSet.add(path);
          }
          return newSet;
        });
      };

      if (value.length === 0) {
        return <span className="json-array">{'[]'}</span>;
      }

      return (
        <div className="json-array">
          <button className="expand-btn" onClick={toggleExpand}>
            [{isExpanded ? '−' : '+'}] Array[{value.length}]
          </button>
          {isExpanded && (
            <ul className="json-array-items">
              {value.map((item, index) => (
                <li key={`${path}[${index}]`} className="json-item">
                  {renderJsonValue(item, `${path}[${index}]`)}
                </li>
              ))}
            </ul>
          )}
        </div>
      );
    } else if (typeof value === 'object' && value !== null) {
      // 对象类型
      const keys = Object.keys(value);
      const isExpanded = expandedPaths.has(path);
      const toggleExpand = () => {
        setExpandedPaths(prev => {
          const newSet = new Set(prev);
          if (newSet.has(path)) {
            newSet.delete(path);
          } else {
            newSet.add(path);
          }
          return newSet;
        });
      };

      if (keys.length === 0) {
        return <span className="json-object">{'{}'}</span>;
      }

      return (
        <div className="json-object">
          <button className="expand-btn" onClick={toggleExpand}>
            [{isExpanded ? '−' : '+'}] Object
          </button>
          {isExpanded && (
            <ul className="json-object-properties">
              {keys.map(key => (
                <li key={`${path}.${key}`} className="json-property">
                  <span className="json-key">{escapeHtml(key)}:</span> {renderJsonValue((value as JsonObject)[key], `${path}.${key}`)}
                </li>
              ))}
            </ul>
          )}
        </div>
      );
    }

    return <span className="json-value">{String(value)}</span>;
  };

  // 截断长文本组件
  const TruncatedText: React.FC<{ text: string }> = ({ text }) => {
    const [expanded, setExpanded] = useState(false);
    const maxLength = 100;

    if (text.length <= maxLength) {
      return <span className="json-string">{escapeHtml(text)}</span>;
    }

    return (
      <div className="json-string-truncated">
        {expanded ? escapeHtml(text) : `${escapeHtml(text.substring(0, maxLength))}...`}
        <button
          className="truncate-toggle-btn"
          onClick={() => setExpanded(!expanded)}
        >
          {expanded ? 'Show Less' : 'Show More'}
        </button>
      </div>
    );
  };

  return (
    <div className="json-display">
      {title && <h4>{title}</h4>}
      <div className="json-content">
        {renderJsonValue(data)}
      </div>
    </div>
  );
};

export default JsonDisplay;