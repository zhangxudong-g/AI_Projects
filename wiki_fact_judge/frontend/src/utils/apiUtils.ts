/**
 * 通用API响应处理工具
 */

// 通用错误处理函数
export const handleApiError = (error: any, defaultMessage: string = "An error occurred"): string => {
  if (error.response) {
    // 服务器响应了错误状态码
    const { status, data } = error.response;
    if (data && data.detail) {
      return typeof data.detail === 'string' ? data.detail : JSON.stringify(data.detail);
    }
    return `Server Error: ${status} - ${defaultMessage}`;
  } else if (error.request) {
    // 请求已发出但没有收到响应
    return "Network Error: Unable to reach the server";
  } else {
    // 其他错误
    return error.message || defaultMessage;
  }
};

// 通用成功消息处理
export const handleApiSuccess = (message: string): void => {
  console.log(`Success: ${message}`);
  // 这里可以添加通知提示等
};

// 通用数据验证函数
export const validateApiResponse = (response: any): boolean => {
  return response && response.data !== undefined;
};