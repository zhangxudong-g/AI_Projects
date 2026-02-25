import React, { useState, useEffect } from 'react';
import { TestReport } from '../types';
import GenericTable from './GenericTable';
import './ReportResultTable.css';

interface ReportResultTableProps {
  testReport: TestReport;
}

// 安全的JSON解析函数，防止原型污染和各种边缘情况
export const safeParseJSON = (jsonString: string) => {
  try {
    // 首先检查输入是否为空或非字符串
    if (!jsonString || typeof jsonString !== 'string') {
      return null;
    }

    // 去除首尾空白字符
    let trimmedString = jsonString.trim();

    // 检查是否是有效的JSON格式
    if (!trimmedString) {
      return null;
    }

    // 尝试处理各种常见的非标准JSON格式
    try {
      // 检查是否包含多个JSON对象
      if (trimmedString.includes('}{')) {
        // 尝试将连续的JSON对象用逗号分隔并包装在数组中
        trimmedString = '[' + trimmedString.replace(/\}\s*\{/g, '},{') + ']';
      } else if (trimmedString.startsWith('{') && trimmedString.endsWith('}') === false) {
        // 如果是以{開始但沒有以}結束，嘗試找到最後一個}
        const lastBraceIndex = trimmedString.lastIndexOf('}');
        if (lastBraceIndex !== -1) {
          trimmedString = trimmedString.substring(0, lastBraceIndex + 1);
        }
      } else if (trimmedString.startsWith('[') && trimmedString.endsWith(']') === false) {
        // 如果是以[開始但沒有以]結束，嘗試找到最後一個]
        const lastBracketIndex = trimmedString.lastIndexOf(']');
        if (lastBracketIndex !== -1) {
          trimmedString = trimmedString.substring(0, lastBracketIndex + 1);
        }
      }
    } catch (e) {
      // 如果修复失败，继续使用原始字符串
      console.warn('Warning: Failed to fix JSON format, using original string:', e);
    }

    // 预处理字符串以防止原型污染
    let sanitized = trimmedString.replace(/"(?:constructor|prototype|__proto__)\s*:/g, '"_"$1:');

    // 处理可能存在的特殊字符问题，特别是撇号或单引号导致的问题
    // 这对于处理复杂的嵌套结构特别有用
    try {
      // 处理Python风格的布尔值和空值
      sanitized = sanitized.replace(/\bTrue\b/g, 'true');
      sanitized = sanitized.replace(/\bFalse\b/g, 'false');
      sanitized = sanitized.replace(/\bNone\b/g, 'null');
      
      // 处理常见的引号问题
      sanitized = sanitized.replace(/(?<!\\)'([^']*)'(?=\s*:)/g, '"$1"'); // 修复键名的单引号
      sanitized = sanitized.replace(/(?<=:\s*)'([^']*)'(?=\s*,|\s*})/g, '"$1"'); // 修复值的单引号
      
      // 处理可能的字典格式问题
      sanitized = sanitized.replace(/'([^']+)':/g, '"$1":'); // 修复键的单引号
      sanitized = sanitized.replace(/:'([^']+)'/g, ':"$1"'); // 修复值的单引号
    } catch (e) {
      // 如果修复失败，继续使用原始字符串
      console.warn('Warning: Failed to fix quote issues, using original string:', e);
    }

    // 再次检查字符串是否有效
    if (!sanitized || sanitized.length === 0) {
      return null;
    }

    // 尝試解析JSON，但確保在最外層捕獲所有錯誤
    let parsed;
    try {
      parsed = JSON.parse(sanitized);
    } catch (parseError) {
      // 如果第一次解析失敗，嘗試更激進的清理
      try {
        // 移除可能導致問題的控制字符
        // eslint-disable-next-line no-control-regex
        const cleanedString = sanitized.replace(/[\u0000-\u001F\u007F-\u009F]/g, '');
        parsed = JSON.parse(cleanedString);
      } catch (secondParseError) {
        // 如果仍然失敗，返回null
        return null;
      }
    }

    // 验證解析後的數據結構
    if (typeof parsed !== 'object' && !Array.isArray(parsed) &&
        typeof parsed !== 'string' && typeof parsed !== 'number' &&
        typeof parsed !== 'boolean') {
      return null; // 不拋出錯誤，而是返回null
    }

    return parsed;
  } catch (e) {
    // 特別捕獲JSON解析錯誤
    if (e instanceof SyntaxError) {
      console.error('JSON parsing error (syntax):', e.message);
    } else {
      console.error('JSON parsing error:', e);
    }
    return null;
  }
};

// HTML转义函数，防止XSS
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

const ReportResultTable: React.FC<ReportResultTableProps> = ({ testReport }) => {
  const [parsedResult, setParsedResult] = useState<any>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [hasError, setHasError] = useState(false);

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

  // 渲染单个结果的表格
  const renderResultTable = (result: any, index?: number) => {
    const title = index !== undefined ? `Result ${index + 1}` : 'Test Result';

    // 准备基本结果数据 - 动态遍历所有字段，不显示 N/A
    const resultData: Record<string, any> = {};
    
    // 遍历 result 对象的所有顶层字段
    if (result && typeof result === 'object') {
      Object.keys(result).forEach(key => {
        const value = result[key];
        // 跳过 null、undefined 和空字符串，但保留 0 和 false
        if (value !== null && value !== undefined && value !== '') {
          // 跳过嵌套对象和数组（这些会单独显示）
          if (typeof value !== 'object' || Array.isArray(value)) {
            // 数字保留 2 位小数
            if (typeof value === 'number') {
              resultData[key] = value.toFixed(2);
            } else {
              resultData[key] = value;
            }
          }
        }
      });
    }

    // 如果没有任何数据，返回空消息
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
        
        {/* 显示details部分 */}
        {result?.details && typeof result.details === 'object' && (
          <div className="details-section">
            <h5>Details</h5>
            <GenericTable data={result.details} />
          </div>
        )}
        
        {/* 显示engineering_action部分 */}
        {result?.engineering_action && typeof result.engineering_action === 'object' && (
          <div className="engineering-action-section">
            <h5>Engineering Action</h5>
            <GenericTable data={result.engineering_action} />
          </div>
        )}
        
        {/* 显示stage_results部分 */}
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
        
        {/* 显示results数组（适用于Plan报告） */}
        {result?.results && Array.isArray(result.results) && (
          <div className="sub-results-section">
            <h5>Sub-Results</h5>
            {result.results.map((subResult: any, idx: number) => (
              <div key={idx} className="sub-result-item">
                <h6>Sub-Result {idx + 1}</h6>
                {subResult.case_id && <p><strong>Case ID:</strong> {subResult.case_id}</p>}
                {subResult.result && typeof subResult.result === 'object' && (
                  <GenericTable data={subResult.result} />
                )}
              </div>
            ))}
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
    // 如果解析失败，尝试显示原始数据
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

  // 如果parsedResult是一个数组（多个测试结果），则显示每个结果
  if (parsedResult && Array.isArray(parsedResult)) {
    return (
      <div className="report-results-table">
        <h4>{testReport.plan_id ? 'Plan Test Results' : 'Test Results'}</h4>
        {parsedResult.map((result, index) => renderResultTable(result, index))}
      </div>
    );
  }

  // 如果parsedResult是一个对象（单个测试结果），则显示详细信息
  if (parsedResult && typeof parsedResult === 'object') {
    // 检查是否是计划执行结果（包含plan_id和results数组）
    if (parsedResult.plan_id !== undefined && Array.isArray(parsedResult.results)) {
      // 这是计划执行结果，显示汇总信息和各个case的结果
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
              // 检查resultObj是否包含嵌套的result属性
              const actualResult = resultObj.result || resultObj;
              return (
                <div key={idx} className="case-result">
                  <h5>Case {idx + 1}: {actualResult.case_id || resultObj.case_id}</h5>
                  {actualResult.result ? renderResultTable(actualResult.result, idx) : renderResultTable(actualResult, idx)}
                </div>
              );
            })}
          </div>
        </div>
      );
    } else {
      // 这是普通的测试结果
      return (
        <div className="report-result-table">
          {renderResultTable(parsedResult)}
        </div>
      );
    }
  }

  // 如果无法解析result字段或result为空，则以表格形式显示testReport中的可用数据
  if (!testReport) {
    return (
      <div className="report-result-table">
        <p>No report data available</p>
      </div>
    );
  }

  // 准备基本报告数据 - 只显示有值的字段
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