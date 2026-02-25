/**
 * 工具函数：从文件名提取文件类型（扩展名）
 * @param fileName 文件名（如：Controller.java）
 * @returns 文件类型（小写扩展名，如 'java'），无扩展名返回 'unknown'
 */
export const extractFileType = (fileName: string): string => {
  if (!fileName) {
    return 'unknown';
  }
  
  // 去掉 .md 后缀（如果是 wiki 文档）
  let name = fileName;
  if (name.endsWith('.md')) {
    name = name.slice(0, -3);
  }
  
  // 提取最后一个 . 之后的部分作为扩展名
  const parts = name.split('.');
  if (parts.length > 1) {
    return parts[parts.length - 1].toLowerCase();
  }
  
  return 'unknown';
};

/**
 * 工具函数：按文件类型对案例结果进行排序
 * 排序规则：
 * 1. 按文件类型分组（java、sql、py 等）
 * 2. 类型间按类型名字母顺序排序
 * 3. 同类型内按 case name 字母顺序排序
 * 4. 无扩展名的 case 排在最后
 * 
 * @param results 案例结果数组
 * @param caseInfoMap case 信息映射表
 * @returns 排序后的数组
 */
export const sortCasesByFileType = <T extends { case_id?: string }>(
  results: T[],
  caseInfoMap: Map<string, { case_id: string; name: string }>
): T[] => {
  return [...results].sort((a, b) => {
    // 获取 case name
    const caseIdA = a.case_id;
    const caseIdB = b.case_id;
    
    const caseInfoA = caseIdA ? caseInfoMap.get(caseIdA) : null;
    const caseInfoB = caseIdB ? caseInfoMap.get(caseIdB) : null;
    
    const nameA = caseInfoA?.name || '';
    const nameB = caseInfoB?.name || '';
    
    // 提取文件类型
    const typeA = extractFileType(nameA);
    const typeB = extractFileType(nameB);
    
    // unknown 类型排在最后
    if (typeA === 'unknown' && typeB !== 'unknown') {
      return 1;
    }
    if (typeA !== 'unknown' && typeB === 'unknown') {
      return -1;
    }
    
    // 类型间按字母排序
    if (typeA !== typeB) {
      return typeA.localeCompare(typeB);
    }
    
    // 同类型内按 name 字母排序
    return nameA.localeCompare(nameB);
  });
};
