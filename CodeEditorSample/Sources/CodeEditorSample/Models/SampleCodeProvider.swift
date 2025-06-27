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
    case markdown
    case yaml
    case xml
    case sql
    case ruby
    case php

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
        case .markdown: "Markdown"
        case .yaml: "YAML"
        case .xml: "XML"
        case .sql: "SQL"
        case .ruby: "Ruby"
        case .php: "PHP"
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
        case .markdown: "md"
        case .yaml: "yaml"
        case .xml: "xml"
        case .sql: "sql"
        case .ruby: "rb"
        case .php: "php"
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
        case .markdown: "text.alignleft"
        case .yaml: "list.bullet"
        case .xml: "chevron.left.forwardslash.chevron.right"
        case .sql: "server.rack"
        case .ruby: "r.square"
        case .php: "p.square"
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
        case .markdown: .purple
        case .yaml: .green
        case .xml: .orange
        case .sql: .mint
        case .ruby: .red
        case .php: .purple
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
        case .markdown:
            markdownSample
        case .yaml:
            yamlSample
        case .xml:
            xmlSample
        case .sql:
            sqlSample
        case .ruby:
            rubySample
        case .php:
            phpSample
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

    // MARK: - Markdown Sample

    private static let markdownSample = """
    # CodeEditor Plugin Documentation

    <!-- TODO: Add installation guide -->
    <!-- FIXME: Update API documentation -->

    The CodeEditor Plugin provides comprehensive code editing capabilities with advanced features like
    syntax highlighting, code completion, and multi-language support.

    ## Features

    ### Syntax Highlighting
    - **15+ languages** supported including Swift, Python, JavaScript, TypeScript, Rust, Go, C++, Java,
      HTML, CSS, JSON, Markdown, YAML, XML, SQL, Ruby, and PHP
    - **SwiftSyntax integration** for Swift AST-based highlighting
    - **Regex-based highlighting** for other languages
    - **Performance optimized** with viewport-based rendering

    ### Code Completion
    - Smart completion suggestions
    - Context-aware proposals
    - Fuzzy matching algorithm
    - Performance monitoring

    ### Advanced Features
    1. **Multi-cursor editing**
    2. **Code folding**
    3. **Search and replace with regex**
    4. **Annotation system** (TODO/FIXME/NOTE/WARNING/ERROR)
    5. **Performance monitoring**
    6. **Plugin marketplace**
    7. **LSP integration**
    8. **Cross-platform support** (macOS/iOS)

    ## Code Examples

    ### Swift
    ```swift
    import SwiftUI

    struct ContentView: View {
        @State private var text = "Hello, World!"
        
        var body: some View {
            Text(text)
                .font(.largeTitle)
        }
    }
    ```

    ### Python
    ```python
    def fibonacci(n):
        if n <= 1:
            return n
        return fibonacci(n-1) + fibonacci(n-2)
    
    # Generate sequence
    sequence = [fibonacci(i) for i in range(10)]
    print(sequence)
    ```

    ### JavaScript
    ```javascript
    const users = [
        { name: 'Alice', age: 30 },
        { name: 'Bob', age: 25 }
    ];

    const adults = users.filter(user => user.age >= 18);
    console.log(adults);
    ```

    ## Configuration

    | Feature | Description | Default |
    |---------|-------------|---------|
    | Line Numbers | Show line numbers | `true` |
    | Syntax Highlighting | Enable highlighting | `true` |
    | Code Completion | Smart suggestions | `true` |
    | Annotations | Show TODO/FIXME | `true` |
    | Minimap | Document overview | `false` |

    ## Links

    - [GitHub Repository](https://github.com/example/CodeEditorPlugin)
    - [Documentation](https://docs.example.com)
    - [API Reference](https://api.example.com)

    ---

    > **Note**: This plugin requires Swift 6.0+ and supports macOS 12.0+, iOS 16.0+
    """

    // MARK: - YAML Sample

    private static let yamlSample = """
    # CodeEditor Plugin Configuration
    # TODO: Add environment-specific configs
    # FIXME: Validate configuration schema

    name: CodeEditorPlugin
    version: 1.0.0
    description: A comprehensive code editor plugin with syntax highlighting

    author:
      name: Developer
      email: developer@example.com
      url: https://example.com

    license: MIT

    keywords:
      - editor
      - syntax-highlighting
      - code
      - ide
      - plugin

    repository:
      type: git
      url: https://github.com/example/code-editor-plugin.git

    engines:
      swift: ">=6.0.0"
      xcode: ">=15.0"

    # Platform support
    platforms:
      macOS:
        minimum: "12.0"
        recommended: "14.0"
      iOS:
        minimum: "16.0"
        recommended: "17.0"
      catalyst:
        minimum: "16.0"

    # Feature configuration
    features:
      syntax_highlighting:
        enabled: true
        languages:
          - swift
          - python
          - javascript
          - typescript
          - rust
          - go
          - cpp
          - java
          - html
          - css
          - json
          - markdown
          - yaml
          - xml
          - sql
          - ruby
          - php
        
      code_completion:
        enabled: true
        fuzzy_matching: true
        max_suggestions: 20
        debounce_ms: 150
        
      annotations:
        enabled: true
        types:
          - TODO
          - FIXME
          - NOTE
          - WARNING
          - ERROR
        styles:
          TODO:
            color: "#007AFF"
            icon: "info.circle"
          FIXME:
            color: "#FF3B30"
            icon: "exclamationmark.triangle"
          NOTE:
            color: "#34C759"
            icon: "note.text"
          WARNING:
            color: "#FF9500"
            icon: "exclamationmark.triangle.fill"
          ERROR:
            color: "#FF3B30"
            icon: "xmark.circle.fill"

    # Performance settings
    performance:
      hardware_acceleration: true
      smooth_scrolling: true
      viewport_rendering: true
      max_file_size_mb: 50
      syntax_highlighting_limit: 100000

    # UI Configuration
    ui:
      theme: auto # auto, light, dark
      font:
        family: "SF Mono"
        size: 14
        weight: regular
      line_numbers:
        enabled: true
        relative: false
      minimap:
        enabled: false
        width: 120
      invisible_characters:
        enabled: false
        show_tabs: true
        show_spaces: false
        show_newlines: false

    # Development settings
    development:
      hot_reload: true
      debug_mode: false
      performance_monitoring: true
      logging:
        level: info
        file: "editor.log"
    """

    // MARK: - XML Sample

    private static let xmlSample = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!-- TODO: Add schema validation -->
    <!-- FIXME: Namespace declarations -->

    <project xmlns="http://maven.apache.org/POM/4.0.0"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
                                 http://maven.apache.org/xsd/maven-4.0.0.xsd">
        
        <modelVersion>4.0.0</modelVersion>
        
        <groupId>com.example</groupId>
        <artifactId>code-editor-plugin</artifactId>
        <version>1.0.0</version>
        <packaging>jar</packaging>
        
        <name>CodeEditor Plugin</name>
        <description>A comprehensive code editor plugin with syntax highlighting</description>
        <url>https://github.com/example/code-editor-plugin</url>
        
        <licenses>
            <license>
                <name>MIT License</name>
                <url>https://opensource.org/licenses/MIT</url>
                <distribution>repo</distribution>
            </license>
        </licenses>
        
        <developers>
            <developer>
                <id>developer</id>
                <name>Developer</name>
                <email>developer@example.com</email>
                <url>https://example.com</url>
                <roles>
                    <role>architect</role>
                    <role>developer</role>
                </roles>
            </developer>
        </developers>
        
        <scm>
            <connection>scm:git:git://github.com/example/code-editor-plugin.git</connection>
            <developerConnection>scm:git:ssh://github.com:example/code-editor-plugin.git</developerConnection>
            <url>https://github.com/example/code-editor-plugin/tree/main</url>
        </scm>
        
        <properties>
            <maven.compiler.source>17</maven.compiler.source>
            <maven.compiler.target>17</maven.compiler.target>
            <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
            <junit.version>5.9.2</junit.version>
            <mockito.version>5.1.1</mockito.version>
        </properties>
        
        <dependencies>
            <!-- Core dependencies -->
            <dependency>
                <groupId>org.springframework</groupId>
                <artifactId>spring-core</artifactId>
                <version>6.0.6</version>
            </dependency>
            
            <dependency>
                <groupId>org.springframework</groupId>
                <artifactId>spring-context</artifactId>
                <version>6.0.6</version>
            </dependency>
            
            <!-- Logging -->
            <dependency>
                <groupId>org.slf4j</groupId>
                <artifactId>slf4j-api</artifactId>
                <version>2.0.6</version>
            </dependency>
            
            <dependency>
                <groupId>ch.qos.logback</groupId>
                <artifactId>logback-classic</artifactId>
                <version>1.4.5</version>
            </dependency>
            
            <!-- Test dependencies -->
            <dependency>
                <groupId>org.junit.jupiter</groupId>
                <artifactId>junit-jupiter</artifactId>
                <version>${junit.version}</version>
                <scope>test</scope>
            </dependency>
            
            <dependency>
                <groupId>org.mockito</groupId>
                <artifactId>mockito-core</artifactId>
                <version>${mockito.version}</version>
                <scope>test</scope>
            </dependency>
        </dependencies>
        
        <build>
            <plugins>
                <plugin>
                    <groupId>org.apache.maven.plugins</groupId>
                    <artifactId>maven-compiler-plugin</artifactId>
                    <version>3.11.0</version>
                    <configuration>
                        <source>17</source>
                        <target>17</target>
                    </configuration>
                </plugin>
                
                <plugin>
                    <groupId>org.apache.maven.plugins</groupId>
                    <artifactId>maven-surefire-plugin</artifactId>
                    <version>3.0.0-M9</version>
                </plugin>
                
                <plugin>
                    <groupId>org.jacoco</groupId>
                    <artifactId>jacoco-maven-plugin</artifactId>
                    <version>0.8.8</version>
                    <executions>
                        <execution>
                            <goals>
                                <goal>prepare-agent</goal>
                            </goals>
                        </execution>
                        <execution>
                            <id>report</id>
                            <phase>test</phase>
                            <goals>
                                <goal>report</goal>
                            </goals>
                        </execution>
                    </executions>
                </plugin>
            </plugins>
        </build>
        
        <profiles>
            <profile>
                <id>release</id>
                <build>
                    <plugins>
                        <plugin>
                            <groupId>org.apache.maven.plugins</groupId>
                            <artifactId>maven-source-plugin</artifactId>
                            <version>3.2.1</version>
                            <executions>
                                <execution>
                                    <id>attach-sources</id>
                                    <goals>
                                        <goal>jar-no-fork</goal>
                                    </goals>
                                </execution>
                            </executions>
                        </plugin>
                        
                        <plugin>
                            <groupId>org.apache.maven.plugins</groupId>
                            <artifactId>maven-javadoc-plugin</artifactId>
                            <version>3.5.0</version>
                            <executions>
                                <execution>
                                    <id>attach-javadocs</id>
                                    <goals>
                                        <goal>jar</goal>
                                    </goals>
                                </execution>
                            </executions>
                        </plugin>
                    </plugins>
                </build>
            </profile>
        </profiles>
    </project>
    """

    // MARK: - SQL Sample

    private static let sqlSample = """
    -- Database schema for CodeEditor Plugin
    -- TODO: Add indexing strategy
    -- FIXME: Optimize query performance

    -- Users table
    CREATE TABLE users (
        id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
        username VARCHAR(50) NOT NULL UNIQUE,
        email VARCHAR(255) NOT NULL UNIQUE,
        password_hash VARCHAR(255) NOT NULL,
        display_name VARCHAR(100),
        avatar_url TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        last_login TIMESTAMP WITH TIME ZONE,
        is_active BOOLEAN DEFAULT TRUE,
        is_verified BOOLEAN DEFAULT FALSE,
        preferences JSONB DEFAULT '{}'::jsonb
    );

    -- User roles
    CREATE TABLE roles (
        id SERIAL PRIMARY KEY,
        name VARCHAR(50) NOT NULL UNIQUE,
        description TEXT,
        permissions JSONB DEFAULT '[]'::jsonb
    );

    -- User-role association
    CREATE TABLE user_roles (
        user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
        role_id INTEGER REFERENCES roles(id) ON DELETE CASCADE,
        granted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        granted_by BIGINT REFERENCES users(id),
        PRIMARY KEY (user_id, role_id)
    );

    -- Projects table
    CREATE TABLE projects (
        id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
        name VARCHAR(100) NOT NULL,
        description TEXT,
        owner_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        visibility VARCHAR(20) DEFAULT 'private' CHECK (visibility IN ('public', 'private', 'internal')),
        language VARCHAR(50),
        repository_url TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        is_archived BOOLEAN DEFAULT FALSE,
        settings JSONB DEFAULT '{}'::jsonb
    );

    -- Code files
    CREATE TABLE files (
        id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
        project_id BIGINT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        path TEXT NOT NULL,
        filename VARCHAR(255) NOT NULL,
        content TEXT,
        language VARCHAR(50),
        size_bytes BIGINT DEFAULT 0,
        line_count INTEGER DEFAULT 0,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        created_by BIGINT REFERENCES users(id),
        updated_by BIGINT REFERENCES users(id),
        UNIQUE(project_id, path)
    );

    -- Code annotations (TODO, FIXME, etc.)
    CREATE TABLE annotations (
        id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
        file_id BIGINT NOT NULL REFERENCES files(id) ON DELETE CASCADE,
        line_number INTEGER NOT NULL,
        column_start INTEGER,
        column_end INTEGER,
        type VARCHAR(20) NOT NULL CHECK (type IN ('TODO', 'FIXME', 'NOTE', 'WARNING', 'ERROR')),
        content TEXT NOT NULL,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        created_by BIGINT REFERENCES users(id),
        resolved_at TIMESTAMP WITH TIME ZONE,
        resolved_by BIGINT REFERENCES users(id)
    );

    -- User sessions
    CREATE TABLE user_sessions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        ip_address INET,
        user_agent TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
        last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        is_active BOOLEAN DEFAULT TRUE
    );

    -- Audit log
    CREATE TABLE audit_log (
        id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
        user_id BIGINT REFERENCES users(id),
        action VARCHAR(100) NOT NULL,
        resource_type VARCHAR(50),
        resource_id BIGINT,
        details JSONB,
        ip_address INET,
        user_agent TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    );

    -- Indexes for performance
    CREATE INDEX idx_users_email ON users(email);
    CREATE INDEX idx_users_username ON users(username);
    CREATE INDEX idx_users_created_at ON users(created_at);

    CREATE INDEX idx_projects_owner_id ON projects(owner_id);
    CREATE INDEX idx_projects_visibility ON projects(visibility);
    CREATE INDEX idx_projects_language ON projects(language);
    CREATE INDEX idx_projects_updated_at ON projects(updated_at);

    CREATE INDEX idx_files_project_id ON files(project_id);
    CREATE INDEX idx_files_language ON files(language);
    CREATE INDEX idx_files_updated_at ON files(updated_at);

    CREATE INDEX idx_annotations_file_id ON annotations(file_id);
    CREATE INDEX idx_annotations_type ON annotations(type);
    CREATE INDEX idx_annotations_created_at ON annotations(created_at);

    CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
    CREATE INDEX idx_user_sessions_expires_at ON user_sessions(expires_at);

    CREATE INDEX idx_audit_log_user_id ON audit_log(user_id);
    CREATE INDEX idx_audit_log_action ON audit_log(action);
    CREATE INDEX idx_audit_log_created_at ON audit_log(created_at);

    -- Sample data
    INSERT INTO roles (name, description, permissions) VALUES
    ('admin', 'System administrator', '["system:admin", "users:manage", "projects:manage"]'::jsonb),
    ('user', 'Regular user', '["projects:create", "files:edit"]'::jsonb),
    ('viewer', 'Read-only access', '["projects:view", "files:view"]'::jsonb);

    INSERT INTO users (username, email, password_hash, display_name) VALUES
    ('admin', 'admin@example.com', '$2b$12$hash1', 'Administrator'),
    ('developer', 'developer@example.com', '$2b$12$hash2', 'Lead Developer'),
    ('user1', 'user1@example.com', '$2b$12$hash3', 'John Doe');

    INSERT INTO user_roles (user_id, role_id) VALUES
    (1, 1), -- admin role
    (2, 2), -- user role
    (3, 2); -- user role

    -- Complex queries
    WITH project_stats AS (
        SELECT 
            p.id,
            p.name,
            p.owner_id,
            COUNT(f.id) as file_count,
            SUM(f.size_bytes) as total_size,
            SUM(f.line_count) as total_lines,
            COUNT(a.id) as annotation_count
        FROM projects p
        LEFT JOIN files f ON p.id = f.project_id
        LEFT JOIN annotations a ON f.id = a.file_id AND a.resolved_at IS NULL
        WHERE p.is_archived = FALSE
        GROUP BY p.id, p.name, p.owner_id
    )
    SELECT 
        ps.*,
        u.display_name as owner_name,
        ROUND(ps.total_size / 1024.0 / 1024.0, 2) as size_mb
    FROM project_stats ps
    JOIN users u ON ps.owner_id = u.id
    ORDER BY ps.total_size DESC
    LIMIT 10;

    -- Performance monitoring query
    SELECT 
        schemaname,
        tablename,
        attname,
        n_distinct,
        correlation
    FROM pg_stats 
    WHERE schemaname = 'public' 
    AND tablename IN ('users', 'projects', 'files', 'annotations')
    ORDER BY tablename, attname;
    """

    // MARK: - Ruby Sample

    private static let rubySample = """
    #!/usr/bin/env ruby
    # frozen_string_literal: true

    # CodeEditor Plugin - Ruby Implementation
    # TODO: Add RuboCop configuration
    # FIXME: Handle encoding issues

    require 'json'
    require 'uri'
    require 'net/http'
    require 'logger'

    # Base repository module
    module Repository
      # Generic repository interface
      class Base
        attr_reader :items

        def initialize
          @items = {}
          @logger = Logger.new($stdout)
        end

        def save(item)
          raise NotImplementedError, 'Subclasses must implement save method'
        end

        def find_by_id(id)
          @items[id]
        end

        def find_all
          @items.values
        end

        def delete(id)
          @items.delete(id)
        end

        def count
          @items.size
        end

        private

        attr_reader :logger
      end
    end

    # User model
    class User
      attr_accessor :id, :name, :email, :roles, :created_at

      def initialize(id:, name:, email:, roles: [])
        @id = id
        @name = name
        @email = email
        @roles = roles
        @created_at = Time.now
      end

      def has_role?(role)
        @roles.include?(role.to_s)
      end

      def admin?
        has_role?(:admin)
      end

      def to_h
        {
          id: @id,
          name: @name,
          email: @email,
          roles: @roles,
          created_at: @created_at.iso8601
        }
      end

      def to_json(*args)
        to_h.to_json(*args)
      end

      def self.from_json(json_str)
        data = JSON.parse(json_str, symbolize_names: true)
        new(
          id: data[:id],
          name: data[:name],
          email: data[:email],
          roles: data[:roles] || []
        )
      end
    end

    # User repository implementation
    class UserRepository < Repository::Base
      def save(user)
        validate!(user)
        @items[user.id] = user
        logger.info("Saved user: #{user.name} (#{user.id})")
        user
      end

      def find_by_email(email)
        @items.values.find { |user| user.email == email }
      end

      def find_by_role(role)
        @items.values.select { |user| user.has_role?(role) }
      end

      def admins
        find_by_role(:admin)
      end

      private

      def validate!(user)
        raise ArgumentError, 'User cannot be nil' if user.nil?
        raise ArgumentError, 'User must have an ID' if user.id.nil?
        raise ArgumentError, 'User must have a name' if user.name.nil? || user.name.empty?
        raise ArgumentError, 'User must have an email' if user.email.nil? || user.email.empty?
        raise ArgumentError, 'Invalid email format' unless valid_email?(user.email)
      end

      def valid_email?(email)
        email.match?(/\\A[\\w+\\-.]+@[a-z\\d\\-]+(\\.[a-z\\d\\-]+)*\\.[a-z]+\\z/i)
      end
    end

    # Service class with error handling
    class UserService
      def initialize(repository: UserRepository.new)
        @repository = repository
        @logger = Logger.new($stdout)
      end

      def create_user(name:, email:, roles: [])
        id = SecureRandom.uuid
        user = User.new(id: id, name: name, email: email, roles: roles)
        
        @repository.save(user)
        @logger.info("Created user: #{user.name}")
        user
      rescue StandardError => e
        @logger.error("Failed to create user: #{e.message}")
        raise
      end

      def get_user_stats
        total_users = @repository.count
        admin_count = @repository.admins.size
        user_count = total_users - admin_count

        {
          total: total_users,
          admins: admin_count,
          users: user_count,
          latest: @repository.find_all.max_by(&:created_at)&.name
        }
      end

      def bulk_import(user_data)
        successful = 0
        failed = 0
        errors = []

        user_data.each do |data|
          begin
            create_user(**data.transform_keys(&:to_sym))
            successful += 1
          rescue StandardError => e
            failed += 1
            errors << { data: data, error: e.message }
          end
        end

        {
          successful: successful,
          failed: failed,
          errors: errors
        }
      end

      private

      attr_reader :repository
    end

    # Configuration class using method_missing
    class Configuration
      def initialize
        @settings = {}
      end

      def method_missing(method_name, *args)
        if method_name.to_s.end_with?('=')
          setting_name = method_name.to_s.chomp('=').to_sym
          @settings[setting_name] = args.first
        elsif @settings.key?(method_name)
          @settings[method_name]
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        method_name.to_s.end_with?('=') || @settings.key?(method_name) || super
      end

      def to_h
        @settings.dup
      end
    end

    # Mixin module for observable behavior
    module Observable
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def observable(*methods)
          methods.each do |method|
            alias_method :"#{method}_without_observer", method

            define_method(method) do |*args, &block|
              result = send(:"#{method}_without_observer", *args, &block)
              notify_observers(method, *args)
              result
            end
          end
        end
      end

      def add_observer(observer)
        @observers ||= []
        @observers << observer
      end

      def notify_observers(method, *args)
        @observers&.each do |observer|
          observer.call(method, *args) if observer.respond_to?(:call)
        end
      end
    end

    # Example usage with blocks and metaprogramming
    class ApplicationRunner
      include Observable

      observable :start, :stop

      def initialize
        @config = Configuration.new
        setup_defaults
      end

      def run
        puts "🚀 Starting CodeEditor Plugin Ruby Demo"
        start

        service = UserService.new
        
        # Create sample users
        users_data = [
          { name: 'Alice Johnson', email: 'alice@example.com', roles: %w[admin user] },
          { name: 'Bob Smith', email: 'bob@example.com', roles: %w[user] },
          { name: 'Charlie Brown', email: 'charlie@example.com', roles: %w[user] }
        ]

        puts "\\n📝 Creating users..."
        result = service.bulk_import(users_data)
        puts "✅ Created #{result[:successful]} users successfully"
        puts "❌ Failed to create #{result[:failed]} users" if result[:failed] > 0

        puts "\\n📊 User Statistics:"
        stats = service.get_user_stats
        stats.each { |key, value| puts "  #{key}: #{value}" }

        puts "\\n🔍 Finding users by role:"
        service.repository.find_by_role(:admin).each do |user|
          puts "  Admin: #{user.name} (#{user.email})"
        end

        puts "\\n💾 Configuration:"
        puts @config.to_h.map { |k, v| "  #{k}: #{v}" }.join("\\n")

        stop
        puts "\\n🏁 Demo completed successfully!"
      rescue StandardError => e
        puts "💥 Error: #{e.message}"
        puts e.backtrace.first(5).map { |line| "  #{line}" }
      end

      private

      def setup_defaults
        @config.app_name = 'CodeEditor Plugin'
        @config.version = '1.0.0'
        @config.debug = true
        @config.max_users = 1000
        
        add_observer(lambda do |method, *args|
          puts "🔔 Observer: #{method} called with #{args}"
        end)
      end

      def start
        puts "▶️  Application started at #{Time.now}"
      end

      def stop
        puts "⏹️  Application stopped at #{Time.now}"
      end
    end

    # Run the application if this file is executed directly
    if __FILE__ == $PROGRAM_NAME
      ApplicationRunner.new.run
    end
    """

    // MARK: - PHP Sample

    private static let phpSample = """
    <?php
    declare(strict_types=1);

    namespace CodeEditor\\Plugin;

    // TODO: Add PSR-4 autoloading
    // FIXME: Implement proper error handling

    use DateTime;
    use Exception;
    use JsonSerializable;
    use InvalidArgumentException;

    /**
     * User entity class
     */
    class User implements JsonSerializable
    {
        private int $id;
        private string $name;
        private string $email;
        private array $roles;
        private DateTime $createdAt;

        public function __construct(int $id, string $name, string $email, array $roles = [])
        {
            $this->validateInput($name, $email);
            
            $this->id = $id;
            $this->name = $name;
            $this->email = $email;
            $this->roles = $roles;
            $this->createdAt = new DateTime();
        }

        public function getId(): int
        {
            return $this->id;
        }

        public function getName(): string
        {
            return $this->name;
        }

        public function getEmail(): string
        {
            return $this->email;
        }

        public function getRoles(): array
        {
            return $this->roles;
        }

        public function hasRole(string $role): bool
        {
            return in_array($role, $this->roles, true);
        }

        public function isAdmin(): bool
        {
            return $this->hasRole('admin');
        }

        public function addRole(string $role): void
        {
            if (!$this->hasRole($role)) {
                $this->roles[] = $role;
            }
        }

        public function removeRole(string $role): void
        {
            $this->roles = array_values(array_filter(
                $this->roles,
                fn($r) => $r !== $role
            ));
        }

        public function jsonSerialize(): array
        {
            return [
                'id' => $this->id,
                'name' => $this->name,
                'email' => $this->email,
                'roles' => $this->roles,
                'created_at' => $this->createdAt->format('c')
            ];
        }

        private function validateInput(string $name, string $email): void
        {
            if (empty(trim($name))) {
                throw new InvalidArgumentException('Name cannot be empty');
            }

            if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
                throw new InvalidArgumentException('Invalid email format');
            }
        }
    }

    /**
     * Generic repository interface
     */
    interface RepositoryInterface
    {
        public function save(object $entity): object;
        public function findById(int $id): ?object;
        public function findAll(): array;
        public function delete(int $id): bool;
        public function count(): int;
    }

    /**
     * User repository implementation
     */
    class UserRepository implements RepositoryInterface
    {
        private array $users = [];
        private int $nextId = 1;

        public function save(object $user): User
        {
            if (!$user instanceof User) {
                throw new InvalidArgumentException('Expected User instance');
            }

            // Generate ID for new users
            if ($user->getId() === 0) {
                $user = new User(
                    $this->nextId++,
                    $user->getName(),
                    $user->getEmail(),
                    $user->getRoles()
                );
            }

            $this->users[$user->getId()] = $user;
            return $user;
        }

        public function findById(int $id): ?User
        {
            return $this->users[$id] ?? null;
        }

        public function findByEmail(string $email): ?User
        {
            foreach ($this->users as $user) {
                if ($user->getEmail() === $email) {
                    return $user;
                }
            }
            return null;
        }

        public function findByRole(string $role): array
        {
            return array_filter(
                $this->users,
                fn(User $user) => $user->hasRole($role)
            );
        }

        public function findAll(): array
        {
            return array_values($this->users);
        }

        public function delete(int $id): bool
        {
            if (isset($this->users[$id])) {
                unset($this->users[$id]);
                return true;
            }
            return false;
        }

        public function count(): int
        {
            return count($this->users);
        }
    }

    /**
     * User service with business logic
     */
    class UserService
    {
        private UserRepository $repository;

        public function __construct(UserRepository $repository = null)
        {
            $this->repository = $repository ?? new UserRepository();
        }

        public function createUser(string $name, string $email, array $roles = ['user']): User
        {
            // Check if user already exists
            if ($this->repository->findByEmail($email) !== null) {
                throw new Exception("User with email '{$email}' already exists");
            }

            $user = new User(0, $name, $email, $roles);
            return $this->repository->save($user);
        }

        public function promoteToAdmin(int $userId): bool
        {
            $user = $this->repository->findById($userId);
            if ($user === null) {
                throw new Exception("User with ID {$userId} not found");
            }

            if (!$user->hasRole('admin')) {
                $user->addRole('admin');
                $this->repository->save($user);
                return true;
            }

            return false;
        }

        public function getUserStats(): array
        {
            $allUsers = $this->repository->findAll();
            $admins = $this->repository->findByRole('admin');

            return [
                'total' => count($allUsers),
                'admins' => count($admins),
                'regular_users' => count($allUsers) - count($admins),
                'latest_user' => $this->getLatestUser($allUsers)?->getName()
            ];
        }

        public function bulkImport(array $userData): array
        {
            $successful = 0;
            $failed = 0;
            $errors = [];

            foreach ($userData as $data) {
                try {
                    $this->createUser(
                        $data['name'] ?? '',
                        $data['email'] ?? '',
                        $data['roles'] ?? ['user']
                    );
                    $successful++;
                } catch (Exception $e) {
                    $failed++;
                    $errors[] = [
                        'data' => $data,
                        'error' => $e->getMessage()
                    ];
                }
            }

            return [
                'successful' => $successful,
                'failed' => $failed,
                'errors' => $errors
            ];
        }

        private function getLatestUser(array $users): ?User
        {
            if (empty($users)) {
                return null;
            }

            usort($users, function (User $a, User $b) {
                return $a->getId() <=> $b->getId();
            });

            return end($users);
        }
    }

    /**
     * Configuration class using magic methods
     */
    class Configuration
    {
        private array $settings = [];

        public function __get(string $name)
        {
            return $this->settings[$name] ?? null;
        }

        public function __set(string $name, $value): void
        {
            $this->settings[$name] = $value;
        }

        public function __isset(string $name): bool
        {
            return isset($this->settings[$name]);
        }

        public function __unset(string $name): void
        {
            unset($this->settings[$name]);
        }

        public function toArray(): array
        {
            return $this->settings;
        }

        public function loadFromArray(array $config): void
        {
            $this->settings = array_merge($this->settings, $config);
        }
    }

    /**
     * Application runner
     */
    class Application
    {
        private UserService $userService;
        private Configuration $config;

        public function __construct()
        {
            $this->userService = new UserService();
            $this->config = new Configuration();
            $this->setupConfiguration();
        }

        public function run(): void
        {
            echo "🚀 Starting CodeEditor Plugin PHP Demo\\n";
            
            try {
                $this->createSampleUsers();
                $this->displayStats();
                $this->demonstrateFeatures();
                
                echo "\\n🏁 Demo completed successfully!\\n";
            } catch (Exception $e) {
                echo "💥 Error: " . $e->getMessage() . "\\n";
                echo "Stack trace:\\n" . $e->getTraceAsString() . "\\n";
            }
        }

        private function setupConfiguration(): void
        {
            $this->config->loadFromArray([
                'app_name' => 'CodeEditor Plugin',
                'version' => '1.0.0',
                'debug' => true,
                'max_users' => 1000,
                'timezone' => 'UTC'
            ]);
        }

        private function createSampleUsers(): void
        {
            echo "\\n📝 Creating sample users...\\n";
            
            $usersData = [
                ['name' => 'Alice Johnson', 'email' => 'alice@example.com', 'roles' => ['admin', 'user']],
                ['name' => 'Bob Smith', 'email' => 'bob@example.com', 'roles' => ['user']],
                ['name' => 'Charlie Brown', 'email' => 'charlie@example.com', 'roles' => ['user']],
                ['name' => 'Diana Prince', 'email' => 'diana@example.com', 'roles' => ['moderator', 'user']]
            ];

            $result = $this->userService->bulkImport($usersData);
            
            echo "✅ Created {$result['successful']} users successfully\\n";
            if ($result['failed'] > 0) {
                echo "❌ Failed to create {$result['failed']} users\\n";
                foreach ($result['errors'] as $error) {
                    echo "  - Error: {$error['error']}\\n";
                }
            }
        }

        private function displayStats(): void
        {
            echo "\\n📊 User Statistics:\\n";
            $stats = $this->userService->getUserStats();
            
            foreach ($stats as $key => $value) {
                echo "  {$key}: {$value}\\n";
            }
        }

        private function demonstrateFeatures(): void
        {
            echo "\\n🔍 Demonstrating features:\\n";
            
            // Find admin users
            $repository = new UserRepository();
            $adminUsers = $repository->findByRole('admin');
            echo "  Admin users: " . count($adminUsers) . "\\n";
            
            // Configuration demo
            echo "\\n💾 Configuration:\\n";
            foreach ($this->config->toArray() as $key => $value) {
                echo "  {$key}: {$value}\\n";
            }
            
            // JSON serialization demo
            if (!empty($adminUsers)) {
                echo "\\n📋 Sample user JSON:\\n";
                echo json_encode($adminUsers[0], JSON_PRETTY_PRINT) . "\\n";
            }
        }
    }

    // Run the application if this file is executed directly
    if (basename(__FILE__) === basename($_SERVER['SCRIPT_NAME'])) {
        $app = new Application();
        $app->run();
    }
    """
}
