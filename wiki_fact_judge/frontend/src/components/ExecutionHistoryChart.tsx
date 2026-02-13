import React from 'react';
import './ExecutionHistoryChart.css';

interface ExecutionRecord {
  id: number;
  timestamp: string;
  score: number;
  status: string;
}

interface ExecutionHistoryChartProps {
  records: ExecutionRecord[];
  title?: string;
}

const ExecutionHistoryChart: React.FC<ExecutionHistoryChartProps> = ({ records, title = "Execution History" }) => {
  if (!records || records.length === 0) {
    return (
      <div className="execution-history-chart">
        <h4>{title}</h4>
        <p>No execution history available</p>
      </div>
    );
  }

  // 按时间排序记录
  const sortedRecords = [...records].sort((a, b) => 
    new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime()
  );

  // 获取分数范围
  const scores = sortedRecords.map(record => record.score);
  const minScore = Math.min(...scores);
  const maxScore = Math.max(...scores);
  const range = maxScore - minScore || 1; // 防止除零

  // 图表尺寸
  const chartHeight = 200;
  const chartWidth = 600;
  const padding = 40;

  // 计算坐标
  const getX = (index: number) => padding + (index * (chartWidth - 2 * padding)) / (sortedRecords.length - 1);
  const getY = (score: number) => chartHeight - padding - ((score - minScore) / range) * (chartHeight - 2 * padding);

  // 生成折线路径
  const linePath = sortedRecords
    .map((record, i) => `${i === 0 ? 'M' : 'L'}${getX(i)},${getY(record.score)}`)
    .join(' ');

  // 生成点
  const dots = sortedRecords.map((record, i) => (
    <g key={record.id}>
      <circle
        cx={getX(i)}
        cy={getY(record.score)}
        r="4"
        fill="#007bff"
      >
        <title>Score: {record.score}, Time: {record.timestamp}</title>
      </circle>
      <text
        x={getX(i)}
        y={getY(record.score) - 10}
        textAnchor="middle"
        fontSize="12"
      >
        {record.score}
      </text>
    </g>
  ));

  // 生成X轴标签
  const xLabels = sortedRecords.map((record, i) => (
    <text
      key={record.id}
      x={getX(i)}
      y={chartHeight - padding + 20}
      textAnchor="middle"
      fontSize="10"
    >
      {new Date(record.timestamp).toLocaleDateString()}
    </text>
  ));

  return (
    <div className="execution-history-chart">
      <h4>{title}</h4>
      <svg width="100%" height={chartHeight + 40} viewBox={`0 0 ${chartWidth} ${chartHeight + 40}`}>
        {/* Y轴标签 */}
        <text x={padding - 10} y={padding} textAnchor="end" fontSize="12">{maxScore.toFixed(1)}</text>
        <text x={padding - 10} y={chartHeight - padding} textAnchor="end" fontSize="12">{minScore.toFixed(1)}</text>
        
        {/* 网格线 */}
        {[0, 0.25, 0.5, 0.75, 1].map((ratio, i) => (
          <g key={i}>
            <line
              x1={padding}
              y1={padding + ratio * (chartHeight - 2 * padding)}
              x2={chartWidth - padding}
              y2={padding + ratio * (chartHeight - 2 * padding)}
              stroke="#eee"
              strokeWidth="1"
            />
          </g>
        ))}

        {/* X轴 */}
        <line
          x1={padding}
          y1={chartHeight - padding}
          x2={chartWidth - padding}
          y2={chartHeight - padding}
          stroke="#333"
          strokeWidth="1"
        />

        {/* Y轴 */}
        <line
          x1={padding}
          y1={padding}
          x2={padding}
          y2={chartHeight - padding}
          stroke="#333"
          strokeWidth="1"
        />

        {/* 折线 */}
        <path d={linePath} fill="none" stroke="#007bff" strokeWidth="2" />

        {/* 数据点 */}
        {dots}

        {/* X轴标签 */}
        {xLabels}
      </svg>
    </div>
  );
};

export default ExecutionHistoryChart;