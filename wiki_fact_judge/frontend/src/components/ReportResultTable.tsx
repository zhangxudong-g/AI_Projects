import React, { useState, useEffect } from 'react';
import { TestReport } from '../types';
import { caseApi } from '../api';
import GenericTable from './GenericTable';
import './ReportResultTable.css';

interface ReportResultTableProps {
  testReport: TestReport;
}

interface CaseInfo {
  case_id: string;
  name: string;
}

interface EngineeringAction {
  level: string;
  description: string;
  recommended_action: string;
}

// 安全的 JSON 解析函数
export const safeParseJSON = (jsonString: string) => {
  try {
    if (!jsonString || typeof jsonString !== 'string') {
      return null;
    }
    let trimmedString = jsonString.trim();
    if (!trimmedString) {
      return null;
    }
    try {
      if (trimmedString.includes('}{')) {
        trimmedString = '[' + trimmedString.replace(/\}\s*\{/g, '},{') + ']';
      } else if (trimmedString.startsWith('{') && trimmedString.endsWith('}') === false) {
        const lastBraceIndex = trimmedString.lastIndexOf('}');
        if (lastBraceIndex !== -1) {
          trimmedString = trimmedString.substring(0, lastBraceIndex + 1);
        }
      } else if (trimmedString.startsWith('[') && trimmedString.endsWith(']') === false) {
        const lastBracketIndex = trimmedString.lastIndexOf(']');
        if (lastBracketIndex !== -1) {
          trimmedString = trimmedString.substring(0, lastBracketIndex + 1);
        }
      }
    } catch (e) {
      console.warn('Warning: Failed to fix JSON format, using original string:', e);
    }
    let sanitized = trimmedString.replace(/"(?:constructor|prototype|__proto__)\s*:/g, '"_"$1:');
    try {
      sanitized = sanitized.replace(/\bTrue\b/g, 'true');
      sanitized = sanitized.replace(/\bFalse\b/g, 'false');
      sanitized = sanitized.replace(/\bNone\b/g, 'null');
    } catch (e) {
      console.warn('Warning: Failed to fix special values:', e);
    }
    if (!sanitized || sanitized.length === 0) {
      return null;
    }
    let parsed;
    try {
      parsed = JSON.parse(sanitized);
    } catch (parseError) {
      try {
        const cleanedString = sanitized.replace(/[\u0000-\u001F\u007F-\u009F]/g, '');
        parsed = JSON.parse(cleanedString);
      } catch (secondParseError) {
        return null;
      }
    }
    return parsed;
  } catch (e) {
    console.error('JSON parsing error:', e);
    return null;
  }
};

const escapeHtml = (unsafe: any): string => {
  if (typeof unsafe !== 'string') {
    unsafe = String(unsafe);
  }
  return unsafe
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
};

// 获取工程建议级别的样式
const getActionLevelStyle = (level: string): string => {
  const levelStyles: Record<string, string> = {
    'PRIMARY_REFERENCE': '#28a745',  // 绿色 - 可作为主要参考
    'SUPPORTING_MATERIAL': '#007bff',  // 蓝色 - 辅助材料
    'NEEDS_REVIEW': '#ffc107',  // 黄色 - 需要审查
    'NOT_RELIABLE': '#dc3545',  // 红色 - 不可靠
  };
  return levelStyles[level] || '#6c757d';
};

// 渲染单个 case 的结果（简化版，突出 Engineering Action）
const renderCaseResult = (result: any, caseInfo: CaseInfo | null, index: number) => {
  const engineeringAction: EngineeringAction | null = result?.engineering_action || null;
  const actionLevelColor = engineeringAction ? getActionLevelStyle(engineeringAction.level) : '#6c757d';

  return (
    <div key={index} className="case-result-card">
      <div className="case-result-header">
        <h5 className="case-title">
          {caseInfo ? (
            <span>
              {caseInfo.name} 
              <span className="case-id">({caseInfo.case_id})</span>
            </span>
          ) : (
            `Case ${index + 1}`
          )}
        </h5>
        <div className="case-score">
          <span className="score-label">Score:</span>
          <span className={`score-value ${result?.final_score >= 80 ? 'score-high' : result?.final_score >= 40 ? 'score-medium' : 'score-low'}`}>
            {result?.final_score?.toFixed(0) || 'N/A'}
          </span>
          <span className={`result-badge ${result?.result === 'PASS' ? 'badge-pass' : 'badge-fail'}`}>
            {result?.result || 'N/A'}
          </span>
        </div>
      </div>

      {/* 突出显示 Engineering Action */}
      {engineeringAction && (
        <div className="engineering-action-highlight" style={{ borderLeftColor: actionLevelColor }}>
          <div className="action-header">
            <strong>Engineering Action:</strong>
            <span className="action-level" style={{ color: actionLevelColor }}>
              {engineeringAction.level}
            </span>
          </div>
          <p className="action-description">{engineeringAction.description}</p>
          <p className="action-recommendation">
            <strong>Recommendation:</strong> {engineeringAction.recommended_action}
          </p>
          {/* 显示 Summary 在 Recommendation 下方 */}
          {result?.summary && (
            <div className="action-summary">
              <strong>Summary:</strong>
              <p>{result.summary}</p>
            </div>
          )}
        </div>
      )}

      {/* 简化的评估维度 */}
      {result?.details && (
        <details className="details-collapse">
          <summary>Assessment Details</summary>
          <div className="details-grid">
            {Object.entries(result.details).map(([key, value]) => (
              <div key={key} className="detail-item">
                <span className="detail-label">{key.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())}:</span>
                <span className="detail-value">{String(value)}</span>
              </div>
            ))}
          </div>
        </details>
      )}
    </div>
  );
};

const ReportResultTable: React.FC<ReportResultTableProps> = ({ testReport }) => {
  const [parsedResult, setParsedResult] = useState<any>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [hasError, setHasError] = useState(false);
  const [caseInfoMap, setCaseInfoMap] = useState<Map<string, CaseInfo>>(new Map());

  useEffect(() => {
    setIsLoading(true);
    setHasError(false);

    try {
      if (testReport?.result) {
        const result = safeParseJSON(testReport.result);
        setParsedResult(result);
        if (result === null) {
          setHasError(true);
        }
      } else {
        setParsedResult(null);
      }
    } catch (error) {
      console.error('Error parsing report result:', error);
      setHasError(true);
      setParsedResult(null);
    } finally {
      setIsLoading(false);
    }
  }, [testReport]);

  // 加载 case 信息
  useEffect(() => {
    const loadCaseInfo = async () => {
      if (!parsedResult || !Array.isArray(parsedResult)) return;

      const caseIds = new Set<string>();
      parsedResult.forEach((result: any) => {
        if (result?.case_id) {
          caseIds.add(result.case_id);
        }
        if (result?.results && Array.isArray(result.results)) {
          result.results.forEach((subResult: any) => {
            if (subResult?.case_id) {
              caseIds.add(subResult.case_id);
            }
          });
        }
      });

      if (caseIds.size === 0) {
        console.log('No case IDs found');
        return;
      }

      console.log('Loading case info for:', Array.from(caseIds));

      // 获取所有 case 的信息
      try {
        const response = await caseApi.getAllCases();
        const allCases = response.data;
        console.log('All cases loaded:', allCases.length);
        const caseInfo = new Map<string, CaseInfo>();
        allCases.forEach((c: any) => {
          if (caseIds.has(c.case_id)) {
            caseInfo.set(c.case_id, {
              case_id: c.case_id,
              name: c.name
            });
          }
        });
        console.log('Case info map size:', caseInfo.size);
        console.log('Case info entries:', Array.from(caseInfo.entries()));
        setCaseInfoMap(caseInfo);
      } catch (error) {
        console.error('Failed to load case info:', error);
      }
    };

    loadCaseInfo();
  }, [parsedResult]);

  if (isLoading) {
    return (
      <div className="report-result-table">
        <p>Loading report results...</p>
      </div>
    );
  }

  if (hasError) {
    if (testReport?.result) {
      return (
        <div className="report-result-table">
          <h4>Test Results (Raw Data)</h4>
          <div className="raw-result-display">
            <pre>{testReport.result}</pre>
          </div>
        </div>
      );
    } else {
      return (
        <div className="report-result-table error-message">
          <p>Failed to parse report results</p>
        </div>
      );
    }
  }

  // 处理 Plan 执行结果（包含 results 数组）
  if (parsedResult && typeof parsedResult === 'object' && Array.isArray(parsedResult.results) && parsedResult.results.length > 0) {
    return (
      <div className="report-result-table">
        <div className="plan-summary-card">
          <h4>Plan Execution Summary</h4>
          <div className="summary-stats">
            <div className="stat-item">
              <span className="stat-label">Total Cases</span>
              <span className="stat-value">{parsedResult.total_cases || parsedResult.results.length}</span>
            </div>
            <div className="stat-item">
              <span className="stat-label">Completed</span>
              <span className="stat-value stat-success">{parsedResult.completed_cases || parsedResult.results.length}</span>
            </div>
            <div className="stat-item">
              <span className="stat-label">Average Score</span>
              <span className="stat-value stat-highlight">{parsedResult.average_score?.toFixed(2) || 'N/A'}</span>
            </div>
          </div>
        </div>

        <div className="plan-cases-section">
          <h4>Case Results</h4>
          <div className="cases-list">
            {parsedResult.results.map((resultObj: any, idx: number) => {
              // 处理嵌套的 result 结构
              const actualResult = resultObj.result && typeof resultObj.result === 'object' ? resultObj.result : resultObj;
              const caseId = actualResult.case_id || resultObj.case_id;
              const caseInfo = caseId ? (caseInfoMap.get(caseId) || null) : null;
              return renderCaseResult(actualResult, caseInfo, idx);
            })}
          </div>
        </div>
      </div>
    );
  }

  // 处理普通测试结果（单个 case）
  if (parsedResult && typeof parsedResult === 'object') {
    return (
      <div className="report-result-table">
        <div className="single-case-result">
          {renderCaseResult(parsedResult, null, 0)}
        </div>
      </div>
    );
  }

  // 无数据
  return (
    <div className="report-result-table">
      <p>No report data available</p>
    </div>
  );
};

export default ReportResultTable;
