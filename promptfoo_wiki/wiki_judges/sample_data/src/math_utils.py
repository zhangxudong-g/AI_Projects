def add_numbers(a: int, b: int) -> int:
    """
    Adds two numbers and returns the result.
    
    Args:
        a (int): The first number
        b (int): The second number
        
    Returns:
        int: The sum of a and b
    """
    return a + b


def subtract_numbers(a: int, b: int) -> int:
    """
    Subtracts the second number from the first and returns the result.
    
    Args:
        a (int): The first number
        b (int): The second number
        
    Returns:
        int: The difference of a and b
    """
    return a - b


def multiply_numbers(a: int, b: int) -> int:
    """
    Multiplies two numbers and returns the result.
    
    Args:
        a (int): The first number
        b (int): The second number
        
    Returns:
        int: The product of a and b
    """
    return a * b


def divide_numbers(a: int, b: int) -> float:
    """
    Divides the first number by the second and returns the result.
    
    Args:
        a (int): The dividend
        b (int): The divisor
        
    Returns:
        float: The quotient of a divided by b
        
    Raises:
        ZeroDivisionError: If b is zero
    """
    if b == 0:
        raise ZeroDivisionError("Cannot divide by zero")
    return a / b