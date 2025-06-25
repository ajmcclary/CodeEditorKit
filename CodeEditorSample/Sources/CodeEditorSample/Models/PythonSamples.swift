import Foundation

// MARK: - Python Samples

enum PythonSamples {
    static let pythonSample = """
    #!/usr/bin/env python3
    # -*- coding: utf-8 -*-

    \"\"\"
    Advanced Python features demonstration
    TODO: Add async examples
    FIXME: Optimize fibonacci calculation
    \"\"\"

    import asyncio
    import functools
    from typing import List, Dict, Optional, Union, TypeVar, Generic
    from dataclasses import dataclass, field
    from abc import ABC, abstractmethod
    import logging

    # Configure logging
    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger(__name__)

    # Type variables
    T = TypeVar('T')

    # Dataclass example
    @dataclass
    class User:
        id: int
        name: str
        email: str
        roles: List[str] = field(default_factory=list)
        metadata: Dict[str, any] = field(default_factory=dict)

        def has_role(self, role: str) -> bool:
            return role in self.roles

        def __post_init__(self):
            logger.info(f"Created user: {self.name}")

    # Generic class
    class Repository(Generic[T], ABC):
        def __init__(self):
            self._items: Dict[int, T] = {}

        @abstractmethod
        def validate(self, item: T) -> bool:
            pass

        def save(self, item: T) -> T:
            if hasattr(item, 'id') and self.validate(item):
                self._items[item.id] = item
                return item
            raise ValueError("Invalid item")

        def find_by_id(self, id: int) -> Optional[T]:
            return self._items.get(id)

        def find_all(self) -> List[T]:
            return list(self._items.values())

    # Concrete implementation
    class UserRepository(Repository[User]):
        def validate(self, user: User) -> bool:
            return bool(user.name and user.email)

        def find_by_email(self, email: str) -> Optional[User]:
            for user in self._items.values():
                if user.email == email:
                    return user
            return None

    # Decorator examples
    def memoize(func):
        cache = {}

        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            key = (args, frozenset(kwargs.items()))
            if key not in cache:
                cache[key] = func(*args, **kwargs)
            return cache[key]

        return wrapper

    def log_calls(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            logger.info(f"Calling {func.__name__} with args={args}, kwargs={kwargs}")
            result = func(*args, **kwargs)
            logger.info(f"{func.__name__} returned {result}")
            return result

        return wrapper

    # Context manager
    class DatabaseConnection:
        def __init__(self, connection_string: str):
            self.connection_string = connection_string
            self.connection = None

        def __enter__(self):
            logger.info(f"Opening connection to {self.connection_string}")
            self.connection = self._connect()
            return self.connection

        def __exit__(self, exc_type, exc_val, exc_tb):
            logger.info("Closing connection")
            if self.connection:
                self.connection.close()

        def _connect(self):
            # Simulate connection
            return type('Connection', (), {'close': lambda: None})()

    # Generator and comprehensions
    @memoize
    def fibonacci(n: int) -> int:
        if n < 2:
            return n
        return fibonacci(n - 1) + fibonacci(n - 2)

    def fibonacci_generator(limit: int):
        a, b = 0, 1
        while a < limit:
            yield a
            a, b = b, a + b

    # Async example
    async def fetch_user_data(user_id: int) -> Dict[str, any]:
        await asyncio.sleep(1)  # Simulate API call
        return {"id": user_id, "name": f"User {user_id}"}

    async def fetch_multiple_users(user_ids: List[int]) -> List[Dict[str, any]]:
        tasks = [fetch_user_data(uid) for uid in user_ids]
        return await asyncio.gather(*tasks)

    # Property example
    class Temperature:
        def __init__(self, celsius: float = 0.0):
            self._celsius = celsius

        @property
        def celsius(self) -> float:
            return self._celsius

        @celsius.setter
        def celsius(self, value: float):
            if value < -273.15:
                raise ValueError("Temperature below absolute zero is not possible")
            self._celsius = value

        @property
        def fahrenheit(self) -> float:
            return self._celsius * 9/5 + 32

        @fahrenheit.setter
        def fahrenheit(self, value: float):
            self.celsius = (value - 32) * 5/9

    # Usage examples
    if __name__ == "__main__":
        # Create user repository
        repo = UserRepository()

        # Create and save users
        user1 = User(1, "Alice", "alice@example.com", ["admin", "user"])
        user2 = User(2, "Bob", "bob@example.com", ["user"])

        repo.save(user1)
        repo.save(user2)

        # Find user
        found = repo.find_by_email("alice@example.com")
        print(f"Found user: {found}")

        # Fibonacci
        fib_sequence = list(fibonacci_generator(100))
        print(f"Fibonacci sequence: {fib_sequence}")

        # Temperature
        temp = Temperature(25)
        print(f"{temp.celsius}°C = {temp.fahrenheit}°F")

        # Async example
        async def main():
            users = await fetch_multiple_users([1, 2, 3])
            print(f"Fetched users: {users}")

        asyncio.run(main())
    """
    
    static let allSamples: [String: String] = [
        "Python Sample": pythonSample
    ]
}
