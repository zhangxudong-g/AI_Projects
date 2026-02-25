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

// ... (safeParseJSON 和 escapeHtml 函数保持不变，省略以节省空间)
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
      sanitized = sanitized.replace(/(?<!\\)'([^']*)'(?=\s*:)/g, '"$1"');
      sanitized = sanitized.replace(/(?<=:\s*)'([^']*)'(?=\s*,|\s*})/g, '"$1"');
      sanitized = sanitized.replace(/'([^']+)':/g, '"$1":');
      sanitized = sanitized.replace(/:'([^']+)'/g, ':"$1"');
    } catch (e) {
      console.warn('Warning: Failed to fix quote issues, using original string:', e);
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
    if (typeof parsed !== 'object' && !Array.isArray(parsed) &&
        typeof parsed !== 'string' && typeof parsed !== 'number' &&
        typeof parsed !== 'boolean') {
      return null;
    }
    return parsed;
  } catch (e) {
    if (e instanceof SyntaxError) {
      console.error('JSON parsing error (syntax):', e.message);
    } else {
      console.error('JSON parsing error:', e);
    }
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

      if (caseIds.size === 0) return;

      try {
        const response = await caseApi.getAllCases();
        const allCases = response.data;
        const caseInfo = new Map<string, CaseInfo>();
        allCases.forEach((c: any) => {
          if (caseIds.has(c.case_id)) {
            caseInfo.set(c.case_id, {
              case_id: c.case_id,
              name: c.name
            });
          }
        });
        setCaseInfoMap(caseInfo);
      } catch (error) {
        console.error('Failed to load case info:', error);
      }
    };

    loadCaseInfo();
  }, [parsedResult]);

  const renderResultTable = (result: any, index?: number) => {
    const title = index !== undefined ? `Result ${index + 1}` : 'Test Result';
    const resultData: Record<string, any> = {};

    if (result && typeof result === 'object') {
      Object.keys(result).forEach(key => {
        const value = result[key];
        if (value !== null && value !== undefined && value !== '') {
          if (typeof value !== 'object' || Array.isArray(value)) {
            if (typeof value === 'number') {
              resultData[key] = value.toFixed(2);
            } else {
              resultData[key] = value;
            }
          }
        }
      });
    }

    if (Object.keys(resultData).length === 0) {
      return (
        <div key={index} className="result-item">
          {index !== undefined && <h5>{title}</h5>}
          <p style={{ color: '#999' }}>暂无详细数据</p>
        </div>
      );
    }

    return (
      <div key={index} className="result-item">
        {index !== undefined && <h5>{title}</h5>}
        <GenericTable data={resultData} />

        {result?.details && typeof result.details === 'object' && (
          <div className="details-section">
            <h5>Details</h5>
            <GenericTable data={result.details} />
          </div>
        )}

        {result?.engineering_action && typeof result.engineering_action === 'object' && (
          <div className="engineering-action-section">
            <h5>Engineering Action</h5>
            <GenericTable data={result.engineering_action} />
          </div>
        )}

        {result?.stage_results && (
          <details>
            <summary>Stage Results</summary>
            <table className="nested-table">
              <thead>
                <tr>
                  <th>Stage</th>
                  <th>Result</th>
                </tr>
              </thead>
              <tbody>
                {Object.entries(result.stage_results).map(([stage, stageResult]) => (
                  <tr key={stage}>
                    <td><strong>{escapeHtml(stage)}:</strong></td>
                    <td>
                      {typeof stageResult === 'object' && stageResult !== null
                        ? <GenericTable data={stageResult} />
                        : escapeHtml(String(stageResult))}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </details>
        )}

        {result?.results && Array.isArray(result.results) && (
          <div className="sub-results-section">
            <h5>Sub-Results</h5>
            {result.results.map((subResult: any, idx: number) => {
              const caseId = subResult?.case_id;
              const caseInfo = caseId ? caseInfoMap.get(caseId) : null;
              return (
                <div key={idx} className="sub-result-item">
                  <h6>
                    Sub-Result {idx + 1}
                    {caseInfo && (
                      <span className="case-name-display">
                        : {caseInfo.name} ({caseInfo.case_id})
                      </span>
                    )}
                  </h6>
                  {subResult.result && typeof subResult.result === 'object' && (
                    <GenericTable data={subResult.result} />
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
    );
  };

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

  if (parsedResult && Array.isArray(parsedResult)) {
    return (
      <div className="report-results-table">
        <h4>{testReport.plan_id ? 'Plan Test Results' : 'Test Results'}</h4>
        {parsedResult.map((result, index) => renderResultTable(result, index))}
      </div>
    );
  }

  if (parsedResult && typeof parsedResult === 'object') {
    if (parsedResult.plan_id !== undefined && Array.isArray(parsedResult.results)) {
      return (
        <div className="report-result-table">
          <div className="plan-summary">
            <h4>Plan Execution Summary</h4>
            <div className="summary-info">
              <p><strong>Total Cases:</strong> {parsedResult.total_cases}</p>
              <p><strong>Completed Cases:</strong> {parsedResult.completed_cases}</p>
              <p><strong>Average Score:</strong> {parsedResult.average_score?.toFixed(2)}</p>
            </div>
          </div>

          <div className="plan-results">
            <h4>Individual Case Results</h4>
            {parsedResult.results.map((resultObj: any, idx: number) => {
              const actualResult = resultObj.result || resultObj;
              const caseId = actualResult.case_id || resultObj.case_id;
              const caseInfo = caseId ? caseInfoMap.get(caseId) : null;
              return (
                <div key={idx} className="case-result">
                  <h5>
                    Case {idx + 1}: 
                    {caseInfo ? (
                      <span className="case-name-display">
                        {caseInfo.name} ({caseInfo.case_id})
                      </span>
                    ) : (
                      caseId || 'Unknown'
                    )}
                  </h5>
                  {actualResult.result ? renderResultTable(actualResult.result, idx) : renderResultTable(actualResult, idx)}
                </div>
              );
            })}
          </div>
        </div>
      );
    } else {
      return (
        <div className="report-result-table">
          {renderResultTable(parsedResult)}
        </div>
      );
    }
  }

  if (!testReport) {
    return (
      <div className="report-result-table">
        <p>No report data available</p>
      </div>
    );
  }

  const basicReportData: Record<string, string | number> = {};
  basicReportData['ID'] = testReport.id;
  if (testReport.report_name) {
    basicReportData['Report Name'] = escapeHtml(testReport.report_name);
  }
  if (testReport.status) {
    basicReportData['Status'] = escapeHtml(testReport.status);
  }
  if (testReport.final_score != null) {
    basicReportData['Final Score'] = testReport.final_score.toFixed(2);
  }
  if (testReport.plan_id != null) {
    basicReportData['Plan ID'] = testReport.plan_id;
  }
  if (testReport.case_id != null) {
    basicReportData['Case ID'] = testReport.case_id;
  }
  if (testReport.output_path) {
    basicReportData['Output Path'] = escapeHtml(testReport.output_path);
  }
  basicReportData['Created At'] = new Date(testReport.created_at).toLocaleString();

  return (
    <div className="report-result-table">
      <GenericTable data={basicReportData} title="Test Results" />
    </div>
  );
};

export default ReportResultTable;
