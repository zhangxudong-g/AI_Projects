import React, { useState, useEffect } from 'react';
import { handleApiError } from '../utils/apiUtils';

export interface TableColumn<T> {
  key: keyof T;
  label: string;
  render?: (value: T[keyof T], item: T) => React.ReactNode;
  sortable?: boolean;
}

interface GenericTableProps<T> {
  data: T[];
  columns: TableColumn<T>[];
  title?: string;
  onRowClick?: (item: T) => void;
  actions?: Array<{
    label: string;
    onClick: (item: T) => void;
    className?: string;
  }>;
  selectable?: boolean;
  selectedItems?: T[];
  onSelectionChange?: (selectedItems: T[]) => void;
  loading?: boolean;
  emptyMessage?: string;
}

function GenericTable<T extends { id?: number | string }>({
  data,
  columns,
  title,
  onRowClick,
  actions,
  selectable = false,
  selectedItems = [],
  onSelectionChange,
  loading = false,
  emptyMessage = "No data available"
}: GenericTableProps<T>) {
  const [sortConfig, setSortConfig] = useState<{ key: keyof T; direction: 'asc' | 'desc' } | null>(null);
  const [localData, setLocalData] = useState<T[]>(data);

  useEffect(() => {
    setLocalData(data);
  }, [data]);

  const handleSort = (key: keyof T) => {
    let direction: 'asc' | 'desc' = 'asc';
    if (sortConfig && sortConfig.key === key && sortConfig.direction === 'asc') {
      direction = 'desc';
    }
    setSortConfig({ key, direction });

    const sortedData = [...localData].sort((a, b) => {
      if (a[key] < b[key]) {
        return direction === 'asc' ? -1 : 1;
      }
      if (a[key] > b[key]) {
        return direction === 'asc' ? -1 : 1;
      }
      return 0;
    });

    setLocalData(sortedData);
  };

  const handleCheckboxChange = (item: T, checked: boolean) => {
    if (!onSelectionChange) return;
    
    if (checked) {
      onSelectionChange([...selectedItems, item]);
    } else {
      onSelectionChange(selectedItems.filter(i => i !== item));
    }
  };

  const handleSelectAll = (checked: boolean) => {
    if (!onSelectionChange) return;
    
    if (checked) {
      onSelectionChange(localData);
    } else {
      onSelectionChange([]);
    }
  };

  const isSelected = (item: T) => {
    return selectedItems.some(i => i.id === item.id);
  };

  const renderCell = (item: T, column: TableColumn<T>) => {
    if (column.render) {
      return column.render(item[column.key], item);
    }
    return String(item[column.key] ?? '');
  };

  if (loading) {
    return (
      <div className="table-container">
        {title && <h3>{title}</h3>}
        <p>Loading...</p>
      </div>
    );
  }

  if (localData.length === 0) {
    return (
      <div className="table-container">
        {title && <h3>{title}</h3>}
        <p>{emptyMessage}</p>
      </div>
    );
  }

  return (
    <div className="table-container">
      {title && <h3>{title}</h3>}
      <table className="table">
        <thead>
          <tr>
            {selectable && (
              <th className="col-checkbox">
                <input
                  type="checkbox"
                  onChange={(e) => handleSelectAll(e.target.checked)}
                  checked={selectedItems.length === localData.length && localData.length > 0}
                />
              </th>
            )}
            {columns.map((column) => (
              <th 
                key={String(column.key)} 
                className={`col-${String(column.key)}`}
                onClick={() => column.sortable ? handleSort(column.key) : undefined}
                style={{ cursor: column.sortable ? 'pointer' : 'default' }}
              >
                {column.label}
                {column.sortable && sortConfig?.key === column.key && (
                  <span>{sortConfig.direction === 'asc' ? ' ↑' : ' ↓'}</span>
                )}
              </th>
            ))}
            {actions && <th className="col-actions">Actions</th>}
          </tr>
        </thead>
        <tbody>
          {localData.map((item, index) => (
            <tr 
              key={item.id || index} 
              onClick={() => onRowClick && onRowClick(item)}
              style={{ cursor: onRowClick ? 'pointer' : 'default' }}
            >
              {selectable && (
                <td>
                  <input
                    type="checkbox"
                    checked={isSelected(item)}
                    onChange={(e) => handleCheckboxChange(item, e.target.checked)}
                  />
                </td>
              )}
              {columns.map((column) => (
                <td key={String(column.key)} title={String(renderCell(item, column))}>
                  {renderCell(item, column)}
                </td>
              ))}
              {actions && (
                <td>
                  <div className="action-buttons">
                    {actions.map((action, idx) => (
                      <button
                        key={idx}
                        className={`btn ${action.className || 'btn-default'} btn-sm`}
                        onClick={(e) => {
                          e.stopPropagation();
                          action.onClick(item);
                        }}
                      >
                        {action.label}
                      </button>
                    ))}
                  </div>
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export default GenericTable;