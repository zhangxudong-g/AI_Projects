# Math Utils 模块文档

Math Utils 是一个简单的数学函数库，提供基本的数学运算功能。

## 功能

- `add_numbers(a, b)` - 返回两个整数的和
- `subtract_numbers(a, b)` - 返回两个整数的差
- `multiply_numbers(a, b)` - 返回两个整数的积
- `divide_numbers(a, b)` - 返回两个数的商，如果除数为0会抛出 ZeroDivisionError

## 使用示例

```python
from math_utils import add_numbers, divide_numbers

result = add_numbers(5, 3)  # 结果为 8
quotient = divide_numbers(10, 2)  # 结果为 5.0
```

## 注意事项

- 所有函数都接受整数参数（除了除法结果为浮点数）
- `divide_numbers` 函数会在除数为0时抛出异常
- 函数都有适当的类型注解和文档字符串