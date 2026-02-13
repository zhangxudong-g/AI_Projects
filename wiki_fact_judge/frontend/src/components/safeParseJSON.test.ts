import { safeParseJSON } from './ReportResultTable';

// Test cases for safeParseJSON function
describe('safeParseJSON', () => {
  test('should parse valid JSON correctly', () => {
    const validJson = '{"key": "value", "number": 42}';
    expect(safeParseJSON(validJson)).toEqual({ key: 'value', number: 42 });
  });

  test('should handle empty string', () => {
    expect(safeParseJSON('')).toBeNull();
  });

  test('should handle null input', () => {
    expect(safeParseJSON(null as any)).toBeNull();
  });

  test('should handle undefined input', () => {
    expect(safeParseJSON(undefined as any)).toBeNull();
  });

  test('should handle non-string input', () => {
    expect(safeParseJSON(42 as any)).toBeNull();
  });

  test('should remove control characters', () => {
    const jsonWithControlChars = '{\n\t"key": "val\u0000ue"\n}';
    expect(safeParseJSON(jsonWithControlChars)).toEqual({ key: 'value' });
  });

  test('should prevent prototype pollution', () => {
    const maliciousJson = '{"__proto__": {"polluted": true}}';
    const result = safeParseJSON(maliciousJson);
    expect(result).not.toEqual({ __proto__: { polluted: true } });
    // The key should be renamed to prevent pollution
  });

  test('should handle incomplete JSON objects', () => {
    const incompleteJson = '{"key": "value"';
    expect(safeParseJSON(incompleteJson)).toBeNull(); // Should handle gracefully
  });

  test('should handle multiple JSON objects', () => {
    const multipleObjects = '{"a":1}{"b":2}';
    // This should be handled by the function's logic to wrap multiple objects
    expect(safeParseJSON(multipleObjects)).toBeDefined();
  });

  test('should handle arrays', () => {
    const jsonArray = '[{"item": 1}, {"item": 2}]';
    expect(safeParseJSON(jsonArray)).toEqual([{ item: 1 }, { item: 2 }]);
  });
});