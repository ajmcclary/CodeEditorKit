// swiftlint:disable file_length type_body_length
import Foundation
import SwiftUI

// MARK: - SampleCode

enum SampleCode: String, CaseIterable {
    case swift
    case javascript
    case typescript
    case python
    case go
    case rust
    case cpp
    case java
    case html
    case css
    case json

    var displayName: String {
        switch self {
        case .swift: "Swift"
        case .javascript: "JavaScript"
        case .typescript: "TypeScript"
        case .python: "Python"
        case .go: "Go"
        case .rust: "Rust"
        case .cpp: "C++"
        case .java: "Java"
        case .html: "HTML"
        case .css: "CSS"
        case .json: "JSON"
        }
    }

    var fileExtension: String {
        switch self {
        case .swift: "swift"
        case .javascript: "js"
        case .typescript: "ts"
        case .python: "py"
        case .go: "go"
        case .rust: "rs"
        case .cpp: "cpp"
        case .java: "java"
        case .html: "html"
        case .css: "css"
        case .json: "json"
        }
    }

    var icon: String {
        switch self {
        case .swift: "swift"
        case .javascript,
             .typescript: "curlybraces"
        case .python: "chevron.left.forwardslash.chevron.right"
        case .go: "g.square"
        case .rust: "r.square"
        case .cpp: "c.square"
        case .java: "cup.and.saucer"
        case .html: "safari"
        case .css: "paintbrush"
        case .json: "doc.text"
        }
    }

    var iconColor: Color {
        switch self {
        case .swift: .orange
        case .javascript: .yellow
        case .typescript: .blue
        case .python: .cyan
        case .go: .teal
        case .rust: .brown
        case .cpp: .indigo
        case .java: .red
        case .html: .orange
        case .css: .blue
        case .json: .gray
        }
    }
}

// MARK: - SampleCodeProvider

enum SampleCodeProvider {
    static func getCode(for sample: SampleCode) -> String {
        switch sample {
        case .swift:
            swiftSample
        case .javascript:
            javascriptSample
        case .typescript:
            typescriptSample
        case .python:
            pythonSample
        case .go:
            goSample
        case .rust:
            rustSample
        case .cpp:
            cppSample
        case .java:
            javaSample
        case .html:
            htmlSample
        case .css:
            cssSample
        case .json:
            jsonSample
        }
    }

    // MARK: - Swift Sample

    private static let swiftSample = """
    import Foundation
    import SwiftUI

    // TODO: Add more documentation
    // FIXME: Handle edge cases in calculation

    /// A sample SwiftUI view demonstrating syntax highlighting
    struct ContentView: View {
        @State private var counter = 0
        @State private var showAlert = false

        var body: some View {
            VStack(spacing: 20) {
                Text("Hello, World!")
                    .font(.largeTitle)
                    .foregroundColor(.primary)

                Text("Counter: \\(counter)")
                    .font(.title2)

                HStack(spacing: 10) {
                    Button(action: increment) {
                        Label("Increment", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: decrement) {
                        Label("Decrement", systemImage: "minus.circle")
                    }
                    .buttonStyle(.bordered)
                }

                // Custom shape with animation
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(width: 200, height: 50)
                    .overlay(
                        Text("\\(counter)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                    )
                    .scaleEffect(showAlert ? 1.1 : 1.0)
                    .animation(.spring(), value: showAlert)
            }
            .padding()
            .alert("Counter Reset", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text("The counter has been reset to 0")
            }
        }

        private func increment() {
            withAnimation {
                counter += 1
            }
        }

        private func decrement() {
            withAnimation {
                counter -= 1
                if counter < 0 {
                    counter = 0
                    showAlert = true
                }
            }
        }
    }

    // Protocol demonstration
    protocol Calculable {
        associatedtype Value: Numeric
        func calculate(_ values: [Value]) -> Value
    }

    struct Calculator<T: Numeric>: Calculable {
        func calculate(_ values: [T]) -> T {
            values.reduce(0, +)
        }
    }

    // Async/await example
    class DataService {
        func fetchData() async throws -> [String] {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return ["Item 1", "Item 2", "Item 3"]
        }
    }
    """

    // MARK: - JavaScript Sample

    private static let javascriptSample = """
    // Modern JavaScript ES6+ features demonstration

    // TODO: Implement error handling
    // FIXME: Memory leak in event listeners

    import { useState, useEffect } from 'react';
    import axios from 'axios';

    // Arrow functions and destructuring
    const fetchUserData = async ({ userId, options = {} }) => {
        try {
            const response = await axios.get(`/api/users/${userId}`, options);
            return response.data;
        } catch (error) {
            console.error('Failed to fetch user:', error);
            throw new Error(`User fetch failed: ${error.message}`);
        }
    };

    // React component with hooks
    export const UserProfile = ({ userId }) => {
        const [user, setUser] = useState(null);
        const [loading, setLoading] = useState(true);
        const [error, setError] = useState(null);

        useEffect(() => {
            let cancelled = false;

            const loadUser = async () => {
                try {
                    setLoading(true);
                    const userData = await fetchUserData({ userId });

                    if (!cancelled) {
                        setUser(userData);
                        setError(null);
                    }
                } catch (err) {
                    if (!cancelled) {
                        setError(err.message);
                    }
                } finally {
                    if (!cancelled) {
                        setLoading(false);
                    }
                }
            };

            loadUser();

            return () => {
                cancelled = true;
            };
        }, [userId]);

        if (loading) return <div className="spinner">Loading...</div>;
        if (error) return <div className="error">Error: {error}</div>;
        if (!user) return null;

        return (
            <div className="user-profile">
                <img src={user.avatar} alt={user.name} />
                <h2>{user.name}</h2>
                <p>{user.bio}</p>
                <div className="stats">
                    <span>Followers: {user.followers}</span>
                    <span>Following: {user.following}</span>
                </div>
            </div>
        );
    };

    // Class with private fields
    class DataProcessor {
        #privateData = [];

        constructor(initialData = []) {
            this.#privateData = [...initialData];
        }

        process(transformer) {
            return this.#privateData.map(transformer);
        }

        get length() {
            return this.#privateData.length;
        }
    }

    // Generator function
    function* fibonacci(n) {
        let a = 0, b = 1;
        for (let i = 0; i < n; i++) {
            yield a;
            [a, b] = [b, a + b];
        }
    }

    // Usage
    const fib = [...fibonacci(10)];
    console.log(fib); // [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]
    """

    // MARK: - TypeScript Sample

    private static let typescriptSample = """
    // TypeScript with advanced type features

    // TODO: Add unit tests
    // FIXME: Type inference issues with generics

    interface User {
        id: string;
        name: string;
        email: string;
        roles: Role[];
        metadata?: Record<string, unknown>;
    }

    enum Role {
        Admin = 'ADMIN',
        User = 'USER',
        Guest = 'GUEST'
    }

    // Generic repository pattern
    abstract class Repository<T extends { id: string }> {
        protected items: Map<string, T> = new Map();

        async findById(id: string): Promise<T | undefined> {
            return this.items.get(id);
        }

        async save(item: T): Promise<T> {
            this.items.set(item.id, item);
            return item;
        }

        async delete(id: string): Promise<boolean> {
            return this.items.delete(id);
        }

        abstract validate(item: T): Promise<boolean>;
    }

    // Concrete implementation
    class UserRepository extends Repository<User> {
        async validate(user: User): Promise<boolean> {
            return !!(user.name && user.email && user.id);
        }

        async findByEmail(email: string): Promise<User | undefined> {
            for (const user of this.items.values()) {
                if (user.email === email) {
                    return user;
                }
            }
            return undefined;
        }
    }

    // Utility types
    type DeepPartial<T> = {
        [P in keyof T]?: T[P] extends object ? DeepPartial<T[P]> : T[P];
    };

    type ReadonlyUser = Readonly<User>;
    type UserUpdate = DeepPartial<Omit<User, 'id'>>;

    // Decorator example
    function Log(target: any, propertyKey: string, descriptor: PropertyDescriptor) {
        const originalMethod = descriptor.value;

        descriptor.value = async function(...args: any[]) {
            console.log(`Calling ${propertyKey} with args:`, args);
            const result = await originalMethod.apply(this, args);
            console.log(`${propertyKey} returned:`, result);
            return result;
        };

        return descriptor;
    }

    // Service class with decorators
    class UserService {
        constructor(private repository: UserRepository) {}

        @Log
        async createUser(data: Omit<User, 'id'>): Promise<User> {
            const user: User = {
                ...data,
                id: crypto.randomUUID(),
            };

            if (await this.repository.validate(user)) {
                return this.repository.save(user);
            }

            throw new Error('Invalid user data');
        }

        @Log
        async updateUser(id: string, updates: UserUpdate): Promise<User | undefined> {
            const user = await this.repository.findById(id);
            if (!user) return undefined;

            const updated = { ...user, ...updates };
            return this.repository.save(updated);
        }
    }

    // Type guards
    function isAdmin(user: User): user is User & { roles: Role[] } {
        return user.roles.includes(Role.Admin);
    }

    // Conditional types
    type IsArray<T> = T extends any[] ? true : false;
    type Test1 = IsArray<string[]>; // true
    type Test2 = IsArray<string>; // false
    """

    // MARK: - Python Sample

    private static let pythonSample = """
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

    // MARK: - Other language samples...

    private static let goSample = """
    package main

    import (
        "context"
        "fmt"
        "log"
        "sync"
        "time"
    )

    // TODO: Add database integration
    // FIXME: Handle concurrent map access

    // User represents a system user
    type User struct {
        ID       int      `json:"id"`
        Name     string   `json:"name"`
        Email    string   `json:"email"`
        Roles    []string `json:"roles"`
        Created  time.Time `json:"created"`
    }

    // Repository interface
    type Repository interface {
        Save(ctx context.Context, user *User) error
        FindByID(ctx context.Context, id int) (*User, error)
        FindAll(ctx context.Context) ([]*User, error)
    }

    // InMemoryRepository implementation
    type InMemoryRepository struct {
        mu    sync.RWMutex
        users map[int]*User
    }

    func NewInMemoryRepository() *InMemoryRepository {
        return &InMemoryRepository{
            users: make(map[int]*User),
        }
    }

    func (r *InMemoryRepository) Save(ctx context.Context, user *User) error {
        r.mu.Lock()
        defer r.mu.Unlock()

        if user.ID == 0 {
            user.ID = len(r.users) + 1
        }
        user.Created = time.Now()
        r.users[user.ID] = user

        return nil
    }

    func main() {
        repo := NewInMemoryRepository()

        // Goroutines and channels
        userCh := make(chan *User, 10)
        errCh := make(chan error, 10)

        // Worker pool
        var wg sync.WaitGroup
        for i := 0; i < 3; i++ {
            wg.Add(1)
            go func(workerID int) {
                defer wg.Done()
                for user := range userCh {
                    log.Printf("Worker %d processing user %s", workerID, user.Name)
                    if err := repo.Save(context.Background(), user); err != nil {
                        errCh <- err
                    }
                }
            }(i)
        }

        // Send users
        users := []*User{
            {Name: "Alice", Email: "alice@example.com"},
            {Name: "Bob", Email: "bob@example.com"},
            {Name: "Charlie", Email: "charlie@example.com"},
        }

        for _, user := range users {
            userCh <- user
        }

        close(userCh)
        wg.Wait()
        close(errCh)

        // Check errors
        for err := range errCh {
            log.Printf("Error: %v", err)
        }

        fmt.Println("Processing complete!")
    }
    """

    private static let rustSample = """
    use std::collections::HashMap;
    use std::sync::{Arc, Mutex};
    use tokio::time::{sleep, Duration};

    // TODO: Implement error handling
    // FIXME: Memory leak in cache implementation

    #[derive(Debug, Clone)]
    struct User {
        id: u64,
        name: String,
        email: String,
        roles: Vec<String>,
    }

    impl User {
        fn new(id: u64, name: impl Into<String>, email: impl Into<String>) -> Self {
            Self {
                id,
                name: name.into(),
                email: email.into(),
                roles: vec![],
            }
        }

        fn has_role(&self, role: &str) -> bool {
            self.roles.iter().any(|r| r == role)
        }
    }

    #[async_trait::async_trait]
    trait Repository<T> {
        async fn save(&mut self, item: T) -> Result<(), String>;
        async fn find_by_id(&self, id: u64) -> Option<T>;
        async fn find_all(&self) -> Vec<T>;
    }

    struct InMemoryRepository {
        users: Arc<Mutex<HashMap<u64, User>>>,
    }

    impl InMemoryRepository {
        fn new() -> Self {
            Self {
                users: Arc::new(Mutex::new(HashMap::new())),
            }
        }
    }

    #[async_trait::async_trait]
    impl Repository<User> for InMemoryRepository {
        async fn save(&mut self, user: User) -> Result<(), String> {
            let mut users = self.users.lock().unwrap();
            users.insert(user.id, user);
            Ok(())
        }

        async fn find_by_id(&self, id: u64) -> Option<User> {
            let users = self.users.lock().unwrap();
            users.get(&id).cloned()
        }

        async fn find_all(&self) -> Vec<User> {
            let users = self.users.lock().unwrap();
            users.values().cloned().collect()
        }
    }

    #[tokio::main]
    async fn main() -> Result<(), Box<dyn std::error::Error>> {
        let mut repo = InMemoryRepository::new();

        // Create users
        let users = vec![
            User::new(1, "Alice", "alice@example.com"),
            User::new(2, "Bob", "bob@example.com"),
            User::new(3, "Charlie", "charlie@example.com"),
        ];

        // Save users concurrently
        let mut handles = vec![];

        for user in users {
            let mut repo_clone = repo.clone();
            let handle = tokio::spawn(async move {
                repo_clone.save(user).await
            });
            handles.push(handle);
        }

        // Wait for all saves to complete
        for handle in handles {
            handle.await??;
        }

        // Retrieve all users
        let all_users = repo.find_all().await;
        println!("All users: {:?}", all_users);

        Ok(())
    }
    """

    private static let cppSample = """
    #include <iostream>
    #include <vector>
    #include <memory>
    #include <algorithm>
    #include <string>
    #include <map>

    // TODO: Add thread safety
    // FIXME: Memory management in Repository

    namespace app {

    // User class with modern C++ features
    class User {
    private:
        int id_;
        std::string name_;
        std::string email_;
        std::vector<std::string> roles_;

    public:
        User(int id, std::string name, std::string email)
            : id_(id), name_(std::move(name)), email_(std::move(email)) {}

        // Getters
        [[nodiscard]] int getId() const noexcept { return id_; }
        [[nodiscard]] const std::string& getName() const noexcept { return name_; }
        [[nodiscard]] const std::string& getEmail() const noexcept { return email_; }

        // Role management
        void addRole(const std::string& role) {
            roles_.push_back(role);
        }

        [[nodiscard]] bool hasRole(const std::string& role) const {
            return std::find(roles_.begin(), roles_.end(), role) != roles_.end();
        }
    };

    // Template repository
    template<typename T>
    class Repository {
    public:
        virtual ~Repository() = default;
        virtual void save(std::shared_ptr<T> item) = 0;
        virtual std::shared_ptr<T> findById(int id) const = 0;
        virtual std::vector<std::shared_ptr<T>> findAll() const = 0;
    };

    // Concrete implementation
    class UserRepository : public Repository<User> {
    private:
        std::map<int, std::shared_ptr<User>> users_;

    public:
        void save(std::shared_ptr<User> user) override {
            users_[user->getId()] = user;
        }

        [[nodiscard]] std::shared_ptr<User> findById(int id) const override {
            auto it = users_.find(id);
            return (it != users_.end()) ? it->second : nullptr;
        }

        [[nodiscard]] std::vector<std::shared_ptr<User>> findAll() const override {
            std::vector<std::shared_ptr<User>> result;
            result.reserve(users_.size());

            for (const auto& [id, user] : users_) {
                result.push_back(user);
            }

            return result;
        }
    };

    // Lambda and algorithm example
    void processUsers(const std::vector<std::shared_ptr<User>>& users) {
        // Count admins
        auto adminCount = std::count_if(users.begin(), users.end(),
            [](const auto& user) { return user->hasRole("admin"); });

        std::cout << "Admin count: " << adminCount << std::endl;

        // Sort by name
        std::vector<std::shared_ptr<User>> sorted = users;
        std::sort(sorted.begin(), sorted.end(),
            [](const auto& a, const auto& b) {
                return a->getName() < b->getName();
            });

        // Print sorted users
        std::for_each(sorted.begin(), sorted.end(),
            [](const auto& user) {
                std::cout << "User: " << user->getName()
                          << " (" << user->getEmail() << ")" << std::endl;
            });
    }

    } // namespace app

    int main() {
        using namespace app;

        auto repo = std::make_unique<UserRepository>();

        // Create users
        auto alice = std::make_shared<User>(1, "Alice", "alice@example.com");
        alice->addRole("admin");
        alice->addRole("user");

        auto bob = std::make_shared<User>(2, "Bob", "bob@example.com");
        bob->addRole("user");

        auto charlie = std::make_shared<User>(3, "Charlie", "charlie@example.com");
        charlie->addRole("user");

        // Save users
        repo->save(alice);
        repo->save(bob);
        repo->save(charlie);

        // Process all users
        auto allUsers = repo->findAll();
        processUsers(allUsers);

        return 0;
    }
    """

    private static let javaSample = """
    package com.example.demo;

    import java.util.*;
    import java.util.concurrent.*;
    import java.util.stream.*;

    // TODO: Add Spring Boot integration
    // FIXME: Thread safety in Repository

    /**
     * User entity class
     */
    public class User {
        private final Long id;
        private final String name;
        private final String email;
        private final Set<Role> roles;

        public User(Long id, String name, String email) {
            this.id = id;
            this.name = name;
            this.email = email;
            this.roles = new HashSet<>();
        }

        public void addRole(Role role) {
            roles.add(role);
        }

        public boolean hasRole(Role role) {
            return roles.contains(role);
        }

        // Getters
        public Long getId() { return id; }
        public String getName() { return name; }
        public String getEmail() { return email; }
        public Set<Role> getRoles() { return Collections.unmodifiableSet(roles); }
    }

    enum Role {
        ADMIN, USER, GUEST
    }

    /**
     * Generic repository interface
     */
    interface Repository<T, ID> {
        CompletableFuture<T> save(T entity);
        CompletableFuture<Optional<T>> findById(ID id);
        CompletableFuture<List<T>> findAll();
    }

    /**
     * In-memory user repository implementation
     */
    class UserRepository implements Repository<User, Long> {
        private final Map<Long, User> users = new ConcurrentHashMap<>();
        private final ExecutorService executor = Executors.newFixedThreadPool(4);

        @Override
        public CompletableFuture<User> save(User user) {
            return CompletableFuture.supplyAsync(() -> {
                users.put(user.getId(), user);
                return user;
            }, executor);
        }

        @Override
        public CompletableFuture<Optional<User>> findById(Long id) {
            return CompletableFuture.supplyAsync(() ->
                Optional.ofNullable(users.get(id)), executor);
        }

        @Override
        public CompletableFuture<List<User>> findAll() {
            return CompletableFuture.supplyAsync(() ->
                new ArrayList<>(users.values()), executor);
        }

        public CompletableFuture<List<User>> findByRole(Role role) {
            return CompletableFuture.supplyAsync(() ->
                users.values().stream()
                    .filter(user -> user.hasRole(role))
                    .collect(Collectors.toList()), executor);
        }
    }

    /**
     * Service layer
     */
    class UserService {
        private final UserRepository repository;

        public UserService(UserRepository repository) {
            this.repository = repository;
        }

        public CompletableFuture<User> createUser(String name, String email) {
            User user = new User(
                ThreadLocalRandom.current().nextLong(1000),
                name,
                email
            );
            user.addRole(Role.USER);
            return repository.save(user);
        }

        public CompletableFuture<List<User>> getAllAdmins() {
            return repository.findByRole(Role.ADMIN);
        }
    }

    /**
     * Main application
     */
    public class Application {
        public static void main(String[] args) throws Exception {
            UserRepository repository = new UserRepository();
            UserService service = new UserService(repository);

            // Create users concurrently
            List<CompletableFuture<User>> futures = Stream.of(
                service.createUser("Alice", "alice@example.com"),
                service.createUser("Bob", "bob@example.com"),
                service.createUser("Charlie", "charlie@example.com")
            ).collect(Collectors.toList());

            // Wait for all to complete
            CompletableFuture.allOf(futures.toArray(new CompletableFuture[0]))
                .thenRun(() -> System.out.println("All users created"))
                .get();

            // Make Alice an admin
            User alice = futures.get(0).get();
            alice.addRole(Role.ADMIN);
            repository.save(alice).get();

            // Find all users
            repository.findAll()
                .thenAccept(users -> {
                    System.out.println("All users:");
                    users.forEach(user ->
                        System.out.println("  - " + user.getName() +
                                          " (" + user.getEmail() + ")"));
                })
                .get();
        }
    }
    """

    private static let htmlSample = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Modern Web App</title>

        <!-- TODO: Add PWA manifest -->
        <!-- FIXME: Optimize CSS loading -->

        <style>
            :root {
                --primary-color: #007bff;
                --secondary-color: #6c757d;
                --background: #f8f9fa;
                --text-color: #212529;
            }

            * {
                box-sizing: border-box;
                margin: 0;
                padding: 0;
            }

            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                background-color: var(--background);
                color: var(--text-color);
                line-height: 1.6;
            }

            .container {
                max-width: 1200px;
                margin: 0 auto;
                padding: 0 20px;
            }
        </style>
    </head>
    <body>
        <header class="header">
            <nav class="navbar">
                <div class="container">
                    <a href="/" class="logo">MyApp</a>
                    <ul class="nav-menu">
                        <li><a href="#home">Home</a></li>
                        <li><a href="#about">About</a></li>
                        <li><a href="#services">Services</a></li>
                        <li><a href="#contact">Contact</a></li>
                    </ul>
                    <button class="hamburger" aria-label="Menu">
                        <span></span>
                        <span></span>
                        <span></span>
                    </button>
                </div>
            </nav>
        </header>

        <main>
            <section class="hero">
                <div class="container">
                    <h1>Welcome to Modern Web Development</h1>
                    <p>Build amazing experiences with HTML5, CSS3, and JavaScript</p>
                    <button class="cta-button">Get Started</button>
                </div>
            </section>

            <section class="features">
                <div class="container">
                    <h2>Features</h2>
                    <div class="feature-grid">
                        <article class="feature-card">
                            <svg class="feature-icon" viewBox="0 0 24 24">
                                <path d="M12 2L2 7v10c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V7l-10-5z"/>
                            </svg>
                            <h3>Secure</h3>
                            <p>Built with security best practices in mind</p>
                        </article>

                        <article class="feature-card">
                            <svg class="feature-icon" viewBox="0 0 24 24">
                                <path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2z"/>
                            </svg>
                            <h3>Responsive</h3>
                            <p>Works perfectly on all devices</p>
                        </article>

                        <article class="feature-card">
                            <svg class="feature-icon" viewBox="0 0 24 24">
                                <path d="M13 3L3.5 13.5c-.7.7-.7 1.8 0 2.5l7 7c.7.7 1.8.7 2.5 0L23 13"/>
                            </svg>
                            <h3>Fast</h3>
                            <p>Optimized for performance</p>
                        </article>
                    </div>
                </div>
            </section>

            <!-- Web Components example -->
            <user-profile
                name="John Doe"
                role="Developer"
                avatar="/images/avatar.jpg">
            </user-profile>
        </main>

        <footer class="footer">
            <div class="container">
                <p>&copy; 2024 MyApp. All rights reserved.</p>
            </div>
        </footer>

        <script>
            // Custom element definition
            class UserProfile extends HTMLElement {
                constructor() {
                    super();
                    this.attachShadow({ mode: 'open' });
                }

                connectedCallback() {
                    const name = this.getAttribute('name') || 'Unknown';
                    const role = this.getAttribute('role') || 'User';
                    const avatar = this.getAttribute('avatar') || '/default-avatar.png';

                    this.shadowRoot.innerHTML = `
                        <style>
                            :host {
                                display: block;
                                padding: 1rem;
                                background: white;
                                border-radius: 8px;
                                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                            }
                            .profile {
                                display: flex;
                                align-items: center;
                                gap: 1rem;
                            }
                            .avatar {
                                width: 60px;
                                height: 60px;
                                border-radius: 50%;
                            }
                            .info h3 {
                                margin: 0;
                                color: #333;
                            }
                            .info p {
                                margin: 0;
                                color: #666;
                            }
                        </style>
                        <div class="profile">
                            <img class="avatar" src="${avatar}" alt="${name}">
                            <div class="info">
                                <h3>${name}</h3>
                                <p>${role}</p>
                            </div>
                        </div>
                    `;
                }
            }

            customElements.define('user-profile', UserProfile);

            // Interactive menu
            document.addEventListener('DOMContentLoaded', () => {
                const hamburger = document.querySelector('.hamburger');
                const navMenu = document.querySelector('.nav-menu');

                hamburger?.addEventListener('click', () => {
                    hamburger.classList.toggle('active');
                    navMenu.classList.toggle('active');
                });
            });
        </script>
    </body>
    </html>
    """

    private static let cssSample = """
    /* Modern CSS with advanced features */

    /* TODO: Add dark mode support */
    /* FIXME: Grid layout issues on Safari */

    /* CSS Variables */
    :root {
        --primary-color: #007bff;
        --secondary-color: #6c757d;
        --success-color: #28a745;
        --danger-color: #dc3545;
        --warning-color: #ffc107;
        --info-color: #17a2b8;

        --font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        --font-size-base: 16px;
        --line-height: 1.6;

        --spacing-unit: 8px;
        --border-radius: 4px;

        --transition-speed: 0.3s;
        --shadow-sm: 0 2px 4px rgba(0, 0, 0, 0.1);
        --shadow-md: 0 4px 6px rgba(0, 0, 0, 0.1);
        --shadow-lg: 0 10px 15px rgba(0, 0, 0, 0.1);
    }

    /* Dark mode variables */
    @media (prefers-color-scheme: dark) {
        :root {
            --background: #1a1a1a;
            --text-color: #e0e0e0;
            --card-background: #2a2a2a;
        }
    }

    /* Reset and base styles */
    *,
    *::before,
    *::after {
        box-sizing: border-box;
    }

    body {
        margin: 0;
        font-family: var(--font-family);
        font-size: var(--font-size-base);
        line-height: var(--line-height);
        color: var(--text-color);
        background-color: var(--background);
    }

    /* Utility classes */
    .container {
        width: 100%;
        max-width: 1200px;
        margin: 0 auto;
        padding: 0 calc(var(--spacing-unit) * 2);
    }

    /* Grid system */
    .grid {
        display: grid;
        gap: calc(var(--spacing-unit) * 3);
        grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    }

    /* Flexbox utilities */
    .flex {
        display: flex;
    }

    .flex-center {
        display: flex;
        justify-content: center;
        align-items: center;
    }

    .flex-between {
        display: flex;
        justify-content: space-between;
        align-items: center;
    }

    /* Components */
    .button {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        padding: calc(var(--spacing-unit) * 1.5) calc(var(--spacing-unit) * 3);
        border: none;
        border-radius: var(--border-radius);
        background-color: var(--primary-color);
        color: white;
        font-size: 1rem;
        font-weight: 500;
        text-decoration: none;
        cursor: pointer;
        transition: all var(--transition-speed) ease;
    }

    .button:hover {
        background-color: color-mix(in srgb, var(--primary-color) 80%, black);
        transform: translateY(-2px);
        box-shadow: var(--shadow-md);
    }

    .button:active {
        transform: translateY(0);
        box-shadow: var(--shadow-sm);
    }

    /* Card component */
    .card {
        background: var(--card-background, white);
        border-radius: calc(var(--border-radius) * 2);
        padding: calc(var(--spacing-unit) * 3);
        box-shadow: var(--shadow-sm);
        transition: box-shadow var(--transition-speed) ease;
    }

    .card:hover {
        box-shadow: var(--shadow-lg);
    }

    /* Form styles */
    .form-group {
        margin-bottom: calc(var(--spacing-unit) * 2);
    }

    .form-label {
        display: block;
        margin-bottom: calc(var(--spacing-unit) * 0.5);
        font-weight: 500;
        color: var(--text-color);
    }

    .form-input {
        width: 100%;
        padding: calc(var(--spacing-unit) * 1.5);
        border: 1px solid #ddd;
        border-radius: var(--border-radius);
        font-size: 1rem;
        transition: border-color var(--transition-speed) ease;
    }

    .form-input:focus {
        outline: none;
        border-color: var(--primary-color);
        box-shadow: 0 0 0 3px rgba(0, 123, 255, 0.1);
    }

    /* Animations */
    @keyframes fadeIn {
        from {
            opacity: 0;
            transform: translateY(20px);
        }
        to {
            opacity: 1;
            transform: translateY(0);
        }
    }

    @keyframes slideIn {
        from {
            transform: translateX(-100%);
        }
        to {
            transform: translateX(0);
        }
    }

    @keyframes pulse {
        0% {
            transform: scale(1);
        }
        50% {
            transform: scale(1.05);
        }
        100% {
            transform: scale(1);
        }
    }

    .animate-fadeIn {
        animation: fadeIn 0.6s ease-out;
    }

    .animate-slideIn {
        animation: slideIn 0.3s ease-out;
    }

    .animate-pulse {
        animation: pulse 2s infinite;
    }

    /* Responsive design */
    @media (max-width: 768px) {
        .container {
            padding: 0 calc(var(--spacing-unit) * 1.5);
        }

        .grid {
            grid-template-columns: 1fr;
        }

        .hide-mobile {
            display: none;
        }
    }

    @media (min-width: 769px) {
        .hide-desktop {
            display: none;
        }
    }

    /* Modern CSS features */
    .gradient-text {
        background: linear-gradient(135deg, var(--primary-color), var(--secondary-color));
        -webkit-background-clip: text;
        background-clip: text;
        -webkit-text-fill-color: transparent;
    }

    .glass-morphism {
        background: rgba(255, 255, 255, 0.1);
        backdrop-filter: blur(10px);
        border: 1px solid rgba(255, 255, 255, 0.2);
    }

    /* Container queries (when supported) */
    @container (min-width: 400px) {
        .container-responsive {
            display: grid;
            grid-template-columns: 1fr 1fr;
        }
    }
    """

    private static let jsonSample = """
    {
      "name": "CodeEditorPlugin",
      "version": "1.0.0",
      "description": "A comprehensive code editor plugin with syntax highlighting",
      "main": "index.js",
      "author": {
        "name": "Developer",
        "email": "developer@example.com",
        "url": "https://example.com"
      },
      "license": "MIT",
      "keywords": [
        "editor",
        "syntax-highlighting",
        "code",
        "ide",
        "plugin"
      ],
      "repository": {
        "type": "git",
        "url": "https://github.com/example/code-editor-plugin.git"
      },
      "bugs": {
        "url": "https://github.com/example/code-editor-plugin/issues"
      },
      "engines": {
        "node": ">=14.0.0",
        "npm": ">=6.0.0"
      },
      "scripts": {
        "start": "node server.js",
        "dev": "nodemon server.js",
        "build": "webpack --mode production",
        "test": "jest",
        "lint": "eslint .",
        "format": "prettier --write ."
      },
      "dependencies": {
        "express": "^4.18.2",
        "lodash": "^4.17.21",
        "axios": "^1.4.0",
        "react": "^18.2.0",
        "react-dom": "^18.2.0"
      },
      "devDependencies": {
        "@types/node": "^20.0.0",
        "@types/react": "^18.0.0",
        "eslint": "^8.42.0",
        "jest": "^29.5.0",
        "nodemon": "^2.0.22",
        "prettier": "^2.8.8",
        "typescript": "^5.1.3",
        "webpack": "^5.88.0"
      },
      "config": {
        "port": 3000,
        "host": "localhost",
        "database": {
          "host": "localhost",
          "port": 5432,
          "name": "editor_db",
          "user": "admin",
          "ssl": true
        }
      },
      "features": {
        "syntaxHighlighting": true,
        "autoComplete": true,
        "linting": true,
        "themes": [
          "dark",
          "light",
          "monokai",
          "solarized"
        ],
        "languages": [
          "javascript",
          "typescript",
          "python",
          "go",
          "rust",
          "swift"
        ]
      }
    }
    """
}
