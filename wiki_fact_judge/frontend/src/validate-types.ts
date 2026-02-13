// 简单的TypeScript类型验证文件
import { TestCase } from './types';
import { TableColumn } from './components/GenericTableOptimized';

// 验证TableColumn类型与TestCase的兼容性
const testCaseColumns: TableColumn<TestCase>[] = [
  { key: 'case_id', label: 'ID', sortable: true },
  { key: 'name', label: 'Name', sortable: true },
  { key: 'created_at', label: 'Created At', sortable: true },
  { 
    key: 'updated_at', 
    label: 'Updated At', 
    sortable: true,
    render: (value: TestCase[keyof TestCase], item: TestCase) => new Date(value as string).toLocaleString()
  }
];

console.log('Type validation passed!');