// swiftlint:disable file_length type_body_length line_length
import Foundation
import SwiftUI

/// A centralized store for sample code that uses LanguageDetectionService
public struct SampleCodeStore {
    
    // MARK: - Sample Code Registry
    
    private static let sampleCodes: [String: String] = [
        "swift": swiftSample,
        "javascript": javascriptSample,
        "typescript": typescriptSample,
        "python": pythonSample,
        "go": goSample,
        "rust": rustSample,
        "cpp": cppSample,
        "c": cSample,
        "java": javaSample,
        "html": htmlSample,
        "css": cssSample,
        "json": jsonSample,
        "markdown": markdownSample,
        "yaml": yamlSample,
        "xml": xmlSample,
        "sql": sqlSample,
        "ruby": rubySample,
        "php": phpSample
    ]
    
    // MARK: - Public Methods
    
    /// Get sample code for a language
    public static func getSampleCode(for languageId: String) -> String? {
        return sampleCodes[languageId]
    }
    
    /// Get sample code for a language info
    public static func getSampleCode(for languageInfo: LanguageDetectionService.LanguageInfo) -> String? {
        return sampleCodes[languageInfo.id]
    }
    
    /// Get all available language samples
    public static func availableSamples() -> [LanguageDetectionService.LanguageInfo] {
        return LanguageDetectionService.allLanguages.filter { language in
            sampleCodes[language.id] != nil
        }
    }
    
    // MARK: - Sample Code Definitions
    
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
    
    private static let typescriptSample = """
    // TypeScript advanced features
    
    // TODO: Add unit tests
    // FIXME: Type inference issues with complex generics
    
    // Interfaces and type aliases
    interface User {
        id: string;
        name: string;
        email: string;
        roles: Role[];
        metadata?: Record<string, unknown>;
    }
    
    type Role = 'admin' | 'user' | 'guest';
    
    // Generic constraints
    class Repository<T extends { id: string }> {
        private items: Map<string, T> = new Map();
        
        add(item: T): void {
            this.items.set(item.id, item);
        }
        
        get(id: string): T | undefined {
            return this.items.get(id);
        }
        
        findAll(predicate?: (item: T) => boolean): T[] {
            const values = Array.from(this.items.values());
            return predicate ? values.filter(predicate) : values;
        }
    }
    
    // Decorators
    function log(target: any, propertyKey: string, descriptor: PropertyDescriptor) {
        const original = descriptor.value;
        descriptor.value = function(...args: any[]) {
            console.log(`Calling ${propertyKey} with args:`, args);
            const result = original.apply(this, args);
            console.log(`Result:`, result);
            return result;
        };
    }
    
    // Conditional types
    type IsArray<T> = T extends any[] ? true : false;
    type UnpackArray<T> = T extends (infer U)[] ? U : T;
    
    // Utility types
    type DeepPartial<T> = {
        [P in keyof T]?: T[P] extends object ? DeepPartial<T[P]> : T[P];
    };
    
    // Async with proper typing
    async function fetchUsers(): Promise<User[]> {
        const response = await fetch('/api/users');
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        return response.json();
    }
    
    // Enums
    enum Status {
        Pending = 'PENDING',
        Active = 'ACTIVE',
        Inactive = 'INACTIVE'
    }
    
    // Type guards
    function isUser(obj: any): obj is User {
        return obj && typeof obj.id === 'string' && typeof obj.name === 'string';
    }
    """
    
    private static let pythonSample = """
    # Python 3.10+ features demonstration
    
    # TODO: Implement caching mechanism
    # FIXME: Handle timezone conversions properly
    
    from typing import List, Dict, Optional, Union, TypeAlias
    from dataclasses import dataclass, field
    from datetime import datetime
    import asyncio
    import json
    
    # Type aliases
    UserID: TypeAlias = str
    Score: TypeAlias = float
    
    # Dataclass with type hints
    @dataclass
    class User:
        id: UserID
        name: str
        email: str
        scores: List[Score] = field(default_factory=list)
        metadata: Dict[str, any] = field(default_factory=dict)
        created_at: datetime = field(default_factory=datetime.now)
        
        def average_score(self) -> Optional[float]:
            if not self.scores:
                return None
            return sum(self.scores) / len(self.scores)
    
    # Context manager
    class DatabaseConnection:
        def __enter__(self):
            print("Opening database connection")
            return self
            
        def __exit__(self, exc_type, exc_val, exc_tb):
            print("Closing database connection")
            
        def query(self, sql: str) -> List[Dict]:
            # Simulated query
            return [{"id": 1, "name": "Example"}]
    
    # Decorator with arguments
    def retry(max_attempts: int = 3, delay: float = 1.0):
        def decorator(func):
            async def wrapper(*args, **kwargs):
                for attempt in range(max_attempts):
                    try:
                        return await func(*args, **kwargs)
                    except Exception as e:
                        if attempt == max_attempts - 1:
                            raise
                        await asyncio.sleep(delay)
                        print(f"Retry {attempt + 1}/{max_attempts}")
            return wrapper
        return decorator
    
    # Async function with type hints
    @retry(max_attempts=3, delay=0.5)
    async def fetch_user_data(user_id: UserID) -> Optional[User]:
        # Simulated API call
        await asyncio.sleep(0.1)
        return User(id=user_id, name="John Doe", email="john@example.com")
    
    # Pattern matching (Python 3.10+)
    def process_value(value: Union[int, str, list, dict]) -> str:
        match value:
            case int(n) if n > 0:
                return f"Positive integer: {n}"
            case int(n) if n < 0:
                return f"Negative integer: {n}"
            case str(s):
                return f"String: '{s}'"
            case [x, y, *rest]:
                return f"List with at least 2 elements"
            case {"type": "user", "name": name}:
                return f"User object with name: {name}"
            case _:
                return "Unknown type"
    
    # Generator with type hints
    def fibonacci(n: int) -> Generator[int, None, None]:
        a, b = 0, 1
        for _ in range(n):
            yield a
            a, b = b, a + b
    
    # Main execution
    async def main():
        user = await fetch_user_data("123")
        print(f"Fetched user: {user.name}")
        
        with DatabaseConnection() as db:
            results = db.query("SELECT * FROM users")
            print(f"Query results: {results}")
    
    if __name__ == "__main__":
        asyncio.run(main())
    """
    
    private static let goSample = """
    package main
    
    import (
        "context"
        "encoding/json"
        "fmt"
        "log"
        "net/http"
        "sync"
        "time"
    )
    
    // TODO: Add metrics collection
    // FIXME: Handle concurrent map writes
    
    // User represents a user in the system
    type User struct {
        ID        string    `json:"id"`
        Name      string    `json:"name"`
        Email     string    `json:"email"`
        CreatedAt time.Time `json:"created_at"`
    }
    
    // Repository interface for data access
    type Repository interface {
        GetUser(ctx context.Context, id string) (*User, error)
        SaveUser(ctx context.Context, user *User) error
        ListUsers(ctx context.Context) ([]*User, error)
    }
    
    // InMemoryRepository implements Repository
    type InMemoryRepository struct {
        mu    sync.RWMutex
        users map[string]*User
    }
    
    // NewInMemoryRepository creates a new repository
    func NewInMemoryRepository() *InMemoryRepository {
        return &InMemoryRepository{
            users: make(map[string]*User),
        }
    }
    
    // GetUser retrieves a user by ID
    func (r *InMemoryRepository) GetUser(ctx context.Context, id string) (*User, error) {
        r.mu.RLock()
        defer r.mu.RUnlock()
        
        user, exists := r.users[id]
        if !exists {
            return nil, fmt.Errorf("user not found: %s", id)
        }
        return user, nil
    }
    
    // SaveUser saves a user
    func (r *InMemoryRepository) SaveUser(ctx context.Context, user *User) error {
        r.mu.Lock()
        defer r.mu.Unlock()
        
        r.users[user.ID] = user
        return nil
    }
    
    // UserHandler handles HTTP requests for users
    type UserHandler struct {
        repo Repository
    }
    
    // ServeHTTP implements http.Handler
    func (h *UserHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
        switch r.Method {
        case http.MethodGet:
            h.handleGet(w, r)
        case http.MethodPost:
            h.handlePost(w, r)
        default:
            http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        }
    }
    
    // Generic function with type constraints
    func Map[T, U any](slice []T, fn func(T) U) []U {
        result := make([]U, len(slice))
        for i, v := range slice {
            result[i] = fn(v)
        }
        return result
    }
    
    // Concurrent processing with channels
    func processItems(items []string) []string {
        ch := make(chan string, len(items))
        var wg sync.WaitGroup
        
        // Process items concurrently
        for _, item := range items {
            wg.Add(1)
            go func(s string) {
                defer wg.Done()
                // Simulate processing
                time.Sleep(10 * time.Millisecond)
                ch <- fmt.Sprintf("Processed: %s", s)
            }(item)
        }
        
        // Wait and collect results
        go func() {
            wg.Wait()
            close(ch)
        }()
        
        var results []string
        for result := range ch {
            results = append(results, result)
        }
        return results
    }
    
    func main() {
        repo := NewInMemoryRepository()
        handler := &UserHandler{repo: repo}
        
        http.Handle("/users", handler)
        
        log.Println("Server starting on :8080")
        if err := http.ListenAndServe(":8080", nil); err != nil {
            log.Fatal(err)
        }
    }
    """
    
    private static let rustSample = """
    // Rust features demonstration
    
    // TODO: Implement proper error handling
    // FIXME: Optimize memory allocation in hot paths
    
    use std::collections::HashMap;
    use std::sync::{Arc, Mutex};
    use tokio::time::{sleep, Duration};
    
    // Struct with derived traits
    #[derive(Debug, Clone, PartialEq)]
    struct User {
        id: String,
        name: String,
        email: String,
        age: Option<u32>,
    }
    
    // Enum with data
    #[derive(Debug)]
    enum Status {
        Active { since: String },
        Inactive,
        Suspended { reason: String },
    }
    
    // Trait definition
    trait Repository {
        type Error;
        
        async fn get_user(&self, id: &str) -> Result<Option<User>, Self::Error>;
        async fn save_user(&self, user: &User) -> Result<(), Self::Error>;
    }
    
    // Generic struct with lifetime
    struct Cache<'a, T> {
        data: HashMap<String, T>,
        name: &'a str,
    }
    
    impl<'a, T: Clone> Cache<'a, T> {
        fn new(name: &'a str) -> Self {
            Self {
                data: HashMap::new(),
                name,
            }
        }
        
        fn get(&self, key: &str) -> Option<&T> {
            self.data.get(key)
        }
        
        fn insert(&mut self, key: String, value: T) {
            self.data.insert(key, value);
        }
    }
    
    // Async function
    async fn fetch_user_data(user_id: &str) -> Result<User, Box<dyn std::error::Error>> {
        // Simulate API call
        sleep(Duration::from_millis(100)).await;
        
        Ok(User {
            id: user_id.to_string(),
            name: "John Doe".to_string(),
            email: "john@example.com".to_string(),
            age: Some(30),
        })
    }
    
    // Pattern matching
    fn process_status(status: &Status) -> String {
        match status {
            Status::Active { since } => format!("Active since {}", since),
            Status::Inactive => "Currently inactive".to_string(),
            Status::Suspended { reason } => format!("Suspended: {}", reason),
        }
    }
    
    // Iterator combinators
    fn process_numbers(numbers: Vec<i32>) -> Vec<i32> {
        numbers.iter()
            .filter(|&&x| x > 0)
            .map(|&x| x * 2)
            .collect()
    }
    
    // Result and Option handling
    fn safe_divide(a: f64, b: f64) -> Result<f64, String> {
        if b == 0.0 {
            Err("Division by zero".to_string())
        } else {
            Ok(a / b)
        }
    }
    
    // Macro definition
    macro_rules! log_debug {
        ($($arg:tt)*) => {
            println!("[DEBUG] {}", format!($($arg)*));
        };
    }
    
    #[tokio::main]
    async fn main() -> Result<(), Box<dyn std::error::Error>> {
        log_debug!("Application starting");
        
        let user = fetch_user_data("123").await?;
        println!("Fetched user: {:?}", user);
        
        let numbers = vec![1, -2, 3, -4, 5];
        let processed = process_numbers(numbers);
        println!("Processed numbers: {:?}", processed);
        
        Ok(())
    }
    """
    
    private static let cppSample = """
    // Modern C++ features demonstration
    
    // TODO: Implement move semantics
    // FIXME: Memory leak in event system
    
    #include <iostream>
    #include <vector>
    #include <memory>
    #include <algorithm>
    #include <functional>
    #include <thread>
    #include <chrono>
    #include <optional>
    #include <variant>
    
    // Template class
    template<typename T>
    class Stack {
    private:
        std::vector<T> elements;
        
    public:
        void push(T const& elem) {
            elements.push_back(elem);
        }
        
        void push(T&& elem) {
            elements.push_back(std::move(elem));
        }
        
        std::optional<T> pop() {
            if (elements.empty()) {
                return std::nullopt;
            }
            T elem = std::move(elements.back());
            elements.pop_back();
            return elem;
        }
        
        bool empty() const {
            return elements.empty();
        }
    };
    
    // Class with modern features
    class User {
    private:
        std::string id;
        std::string name;
        std::string email;
        
    public:
        // Constructor with member initializer list
        User(std::string id, std::string name, std::string email)
            : id(std::move(id)), name(std::move(name)), email(std::move(email)) {}
        
        // Copy constructor
        User(const User& other) = default;
        
        // Move constructor
        User(User&& other) noexcept = default;
        
        // Getters
        [[nodiscard]] const std::string& getId() const { return id; }
        [[nodiscard]] const std::string& getName() const { return name; }
        [[nodiscard]] const std::string& getEmail() const { return email; }
    };
    
    // Lambda and functional programming
    template<typename Container, typename Predicate>
    auto filter(const Container& cont, Predicate pred) {
        Container result;
        std::copy_if(cont.begin(), cont.end(), 
                     std::back_inserter(result), pred);
        return result;
    }
    
    // Variadic template
    template<typename... Args>
    void log(Args&&... args) {
        ((std::cout << args << " "), ...);
        std::cout << std::endl;
    }
    
    // Smart pointers
    class Resource {
    private:
        std::string name;
        
    public:
        explicit Resource(std::string name) : name(std::move(name)) {
            std::cout << "Resource " << this->name << " created" << std::endl;
        }
        
        ~Resource() {
            std::cout << "Resource " << name << " destroyed" << std::endl;
        }
        
        void use() const {
            std::cout << "Using resource " << name << std::endl;
        }
    };
    
    // Concepts (C++20)
    template<typename T>
    concept Numeric = std::is_arithmetic_v<T>;
    
    template<Numeric T>
    T add(T a, T b) {
        return a + b;
    }
    
    // Coroutine example (C++20)
    #include <coroutine>
    
    struct Task {
        struct promise_type {
            Task get_return_object() { return {}; }
            std::suspend_never initial_suspend() { return {}; }
            std::suspend_never final_suspend() noexcept { return {}; }
            void return_void() {}
            void unhandled_exception() {}
        };
    };
    
    Task simpleCoroutine() {
        std::cout << "Coroutine started" << std::endl;
        co_await std::suspend_always{};
        std::cout << "Coroutine resumed" << std::endl;
    }
    
    int main() {
        // Using auto and structured bindings
        auto [x, y] = std::make_pair(10, 20);
        log("Pair values:", x, y);
        
        // Using smart pointers
        {
            auto resource = std::make_unique<Resource>("MainResource");
            resource->use();
        }
        
        // Using lambda
        std::vector<int> numbers = {1, 2, 3, 4, 5};
        auto evens = filter(numbers, [](int n) { return n % 2 == 0; });
        
        // Range-based for loop
        for (const auto& n : evens) {
            std::cout << n << " ";
        }
        std::cout << std::endl;
        
        return 0;
    }
    """
    
    private static let cSample = """
    // C programming features demonstration
    
    // TODO: Add error handling macros
    // FIXME: Buffer overflow in string operations
    
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include <stdbool.h>
    
    // Constants
    #define MAX_NAME_LENGTH 100
    #define MAX_USERS 1000
    
    // Struct definition
    typedef struct {
        int id;
        char name[MAX_NAME_LENGTH];
        char email[MAX_NAME_LENGTH];
        bool active;
    } User;
    
    // Function prototypes
    User* create_user(int id, const char* name, const char* email);
    void destroy_user(User* user);
    void print_user(const User* user);
    
    // Linked list node
    typedef struct Node {
        void* data;
        struct Node* next;
    } Node;
    
    // Linked list
    typedef struct {
        Node* head;
        Node* tail;
        size_t size;
    } LinkedList;
    
    // Create a new user
    User* create_user(int id, const char* name, const char* email) {
        User* user = (User*)malloc(sizeof(User));
        if (user == NULL) {
            fprintf(stderr, "Memory allocation failed\\n");
            return NULL;
        }
        
        user->id = id;
        strncpy(user->name, name, MAX_NAME_LENGTH - 1);
        user->name[MAX_NAME_LENGTH - 1] = '\\0';
        strncpy(user->email, email, MAX_NAME_LENGTH - 1);
        user->email[MAX_NAME_LENGTH - 1] = '\\0';
        user->active = true;
        
        return user;
    }
    
    // Destroy a user
    void destroy_user(User* user) {
        if (user != NULL) {
            free(user);
        }
    }
    
    // Print user information
    void print_user(const User* user) {
        if (user == NULL) return;
        
        printf("User ID: %d\\n", user->id);
        printf("Name: %s\\n", user->name);
        printf("Email: %s\\n", user->email);
        printf("Active: %s\\n", user->active ? "Yes" : "No");
        printf("\\n");
    }
    
    // Create linked list
    LinkedList* create_list() {
        LinkedList* list = (LinkedList*)malloc(sizeof(LinkedList));
        if (list == NULL) return NULL;
        
        list->head = NULL;
        list->tail = NULL;
        list->size = 0;
        
        return list;
    }
    
    // Add to list
    bool add_to_list(LinkedList* list, void* data) {
        if (list == NULL) return false;
        
        Node* node = (Node*)malloc(sizeof(Node));
        if (node == NULL) return false;
        
        node->data = data;
        node->next = NULL;
        
        if (list->tail == NULL) {
            list->head = node;
            list->tail = node;
        } else {
            list->tail->next = node;
            list->tail = node;
        }
        
        list->size++;
        return true;
    }
    
    // Function pointer example
    typedef int (*CompareFunc)(const void*, const void*);
    
    int compare_users_by_id(const void* a, const void* b) {
        const User* user_a = (const User*)a;
        const User* user_b = (const User*)b;
        return user_a->id - user_b->id;
    }
    
    // Main function
    int main() {
        printf("C Programming Demo\\n");
        printf("==================\\n\\n");
        
        // Create users
        User* user1 = create_user(1, "Alice", "alice@example.com");
        User* user2 = create_user(2, "Bob", "bob@example.com");
        
        if (user1 && user2) {
            print_user(user1);
            print_user(user2);
            
            // Create list and add users
            LinkedList* list = create_list();
            if (list) {
                add_to_list(list, user1);
                add_to_list(list, user2);
                
                printf("List size: %zu\\n", list->size);
                
                // Cleanup would go here
                // (omitted for brevity)
            }
        }
        
        // Cleanup
        destroy_user(user1);
        destroy_user(user2);
        
        return 0;
    }
    """
    
    private static let javaSample = """
    // Java features demonstration
    
    // TODO: Implement dependency injection
    // FIXME: Thread safety issues in singleton
    
    import java.util.*;
    import java.util.concurrent.*;
    import java.util.stream.*;
    import java.time.*;
    import java.util.function.*;
    
    // Main class
    public class UserService {
        private final Map<String, User> users = new ConcurrentHashMap<>();
        private final ExecutorService executor = Executors.newFixedThreadPool(10);
        
        // User record (Java 14+)
        public record User(
            String id,
            String name,
            String email,
            LocalDateTime createdAt,
            List<String> roles
        ) {
            // Compact constructor
            public User {
                Objects.requireNonNull(id, "ID cannot be null");
                Objects.requireNonNull(name, "Name cannot be null");
                Objects.requireNonNull(email, "Email cannot be null");
                roles = List.copyOf(roles); // Defensive copy
            }
        }
        
        // Sealed class (Java 15+)
        public sealed interface Event permits UserCreated, UserUpdated, UserDeleted {
            String userId();
            LocalDateTime timestamp();
        }
        
        public record UserCreated(String userId, LocalDateTime timestamp) implements Event {}
        public record UserUpdated(String userId, LocalDateTime timestamp) implements Event {}
        public record UserDeleted(String userId, LocalDateTime timestamp) implements Event {}
        
        // Generic method with bounded type
        public <T extends Comparable<T>> T findMax(List<T> list) {
            return list.stream()
                .max(Comparator.naturalOrder())
                .orElseThrow(() -> new NoSuchElementException("List is empty"));
        }
        
        // Async method
        public CompletableFuture<User> createUserAsync(String name, String email) {
            return CompletableFuture.supplyAsync(() -> {
                String id = UUID.randomUUID().toString();
                User user = new User(
                    id,
                    name,
                    email,
                    LocalDateTime.now(),
                    List.of("user")
                );
                users.put(id, user);
                return user;
            }, executor);
        }
        
        // Stream operations
        public List<User> findUsersByRole(String role) {
            return users.values().stream()
                .filter(user -> user.roles().contains(role))
                .sorted(Comparator.comparing(User::name))
                .collect(Collectors.toList());
        }
        
        // Optional usage
        public Optional<User> findUserById(String id) {
            return Optional.ofNullable(users.get(id));
        }
        
        // Pattern matching (Java 17+)
        public String processEvent(Event event) {
            return switch (event) {
                case UserCreated(var id, var time) -> 
                    String.format("User %s created at %s", id, time);
                case UserUpdated(var id, var time) -> 
                    String.format("User %s updated at %s", id, time);
                case UserDeleted(var id, var time) -> 
                    String.format("User %s deleted at %s", id, time);
            };
        }
        
        // Try-with-resources
        public void processFile(String filename) {
            try (var reader = new BufferedReader(new FileReader(filename))) {
                reader.lines()
                    .filter(line -> !line.isEmpty())
                    .forEach(System.out::println);
            } catch (IOException e) {
                System.err.println("Error reading file: " + e.getMessage());
            }
        }
        
        // Text blocks (Java 15+)
        public String getHelpText() {
            return \"\"\"
                UserService Help
                ================
                
                Available commands:
                  create <name> <email> - Create a new user
                  find <id>            - Find user by ID
                  list                 - List all users
                  help                 - Show this help
                \"\"\";
        }
        
        // Main method
        public static void main(String[] args) {
            var service = new UserService();
            
            // Create users asynchronously
            var future1 = service.createUserAsync("Alice", "alice@example.com");
            var future2 = service.createUserAsync("Bob", "bob@example.com");
            
            // Wait for completion
            CompletableFuture.allOf(future1, future2).join();
            
            System.out.println("Users created successfully");
            
            // Shutdown executor
            service.executor.shutdown();
        }
    }
    """
    
    private static let htmlSample = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Modern HTML5 Example</title>
        
        <!-- TODO: Add meta tags for SEO -->
        <!-- FIXME: Improve accessibility attributes -->
        
        <style>
            :root {
                --primary-color: #3498db;
                --secondary-color: #2ecc71;
                --text-color: #333;
                --bg-color: #f4f4f4;
            }
            
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                color: var(--text-color);
                background-color: var(--bg-color);
                margin: 0;
                padding: 0;
                line-height: 1.6;
            }
        </style>
    </head>
    <body>
        <!-- Header with navigation -->
        <header role="banner">
            <nav aria-label="Main navigation">
                <ul>
                    <li><a href="#home">Home</a></li>
                    <li><a href="#about">About</a></li>
                    <li><a href="#services">Services</a></li>
                    <li><a href="#contact">Contact</a></li>
                </ul>
            </nav>
        </header>
        
        <!-- Main content -->
        <main role="main">
            <article>
                <h1>Welcome to Our Website</h1>
                
                <!-- Section with semantic HTML5 elements -->
                <section id="features">
                    <h2>Features</h2>
                    
                    <!-- Feature cards -->
                    <div class="feature-grid">
                        <div class="feature-card">
                            <figure>
                                <img src="feature1.jpg" alt="Feature 1 illustration" loading="lazy">
                                <figcaption>Advanced Analytics</figcaption>
                            </figure>
                            <p>Track your progress with our comprehensive analytics dashboard.</p>
                        </div>
                        
                        <div class="feature-card">
                            <picture>
                                <source srcset="feature2.webp" type="image/webp">
                                <source srcset="feature2.jpg" type="image/jpeg">
                                <img src="feature2.jpg" alt="Feature 2 illustration" loading="lazy">
                            </picture>
                            <p>Responsive design that works on all devices.</p>
                        </div>
                    </div>
                </section>
                
                <!-- Form with validation -->
                <section id="contact">
                    <h2>Contact Us</h2>
                    <form action="/submit" method="POST" novalidate>
                        <div class="form-group">
                            <label for="name">Name:</label>
                            <input type="text" id="name" name="name" required 
                                   aria-describedby="name-error">
                            <span id="name-error" class="error" aria-live="polite"></span>
                        </div>
                        
                        <div class="form-group">
                            <label for="email">Email:</label>
                            <input type="email" id="email" name="email" required 
                                   pattern="[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,}$">
                        </div>
                        
                        <div class="form-group">
                            <label for="message">Message:</label>
                            <textarea id="message" name="message" rows="5" required></textarea>
                        </div>
                        
                        <button type="submit">Send Message</button>
                    </form>
                </section>
                
                <!-- Details/Summary element -->
                <details>
                    <summary>More Information</summary>
                    <p>This is additional information that can be toggled.</p>
                </details>
                
                <!-- Time element -->
                <p>Last updated: <time datetime="2024-01-15T10:30:00Z">January 15, 2024</time></p>
            </article>
            
            <!-- Aside for supplementary content -->
            <aside>
                <h3>Related Links</h3>
                <ul>
                    <li><a href="#" rel="noopener noreferrer">External Resource</a></li>
                    <li><a href="#" download>Download PDF</a></li>
                </ul>
            </aside>
        </main>
        
        <!-- Footer -->
        <footer role="contentinfo">
            <p>&copy; 2024 Your Company. All rights reserved.</p>
            <address>
                Contact us at <a href="mailto:info@example.com">info@example.com</a>
            </address>
        </footer>
        
        <!-- Script with type module -->
        <script type="module">
            // Form validation
            const form = document.querySelector('form');
            const nameInput = document.getElementById('name');
            const nameError = document.getElementById('name-error');
            
            nameInput.addEventListener('blur', () => {
                if (!nameInput.validity.valid) {
                    nameError.textContent = 'Please enter your name';
                } else {
                    nameError.textContent = '';
                }
            });
        </script>
    </body>
    </html>
    """
    
    private static let cssSample = """
    /* Modern CSS with advanced features */
    
    /* TODO: Add dark mode support */
    /* FIXME: Grid layout issues on Safari */
    
    /* CSS Custom Properties */
    :root {
        --primary-color: #3498db;
        --secondary-color: #2ecc71;
        --danger-color: #e74c3c;
        --warning-color: #f39c12;
        --text-color: #2c3e50;
        --bg-color: #ecf0f1;
        --border-radius: 8px;
        --transition-speed: 0.3s;
        --max-width: 1200px;
    }
    
    /* CSS Reset */
    *,
    *::before,
    *::after {
        box-sizing: border-box;
        margin: 0;
        padding: 0;
    }
    
    /* Grid Layout */
    .container {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
        gap: 2rem;
        max-width: var(--max-width);
        margin: 0 auto;
        padding: 2rem;
    }
    
    /* Flexbox with gap */
    .card {
        display: flex;
        flex-direction: column;
        gap: 1rem;
        background: white;
        border-radius: var(--border-radius);
        padding: 1.5rem;
        box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
        transition: transform var(--transition-speed) ease,
                    box-shadow var(--transition-speed) ease;
    }
    
    .card:hover {
        transform: translateY(-5px);
        box-shadow: 0 5px 20px rgba(0, 0, 0, 0.15);
    }
    
    /* Modern Button Styles */
    .btn {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        gap: 0.5rem;
        padding: 0.75rem 1.5rem;
        border: none;
        border-radius: var(--border-radius);
        font-size: 1rem;
        font-weight: 500;
        text-decoration: none;
        cursor: pointer;
        transition: all var(--transition-speed) ease;
        position: relative;
        overflow: hidden;
    }
    
    .btn::before {
        content: '';
        position: absolute;
        top: 50%;
        left: 50%;
        width: 0;
        height: 0;
        background: rgba(255, 255, 255, 0.2);
        border-radius: 50%;
        transform: translate(-50%, -50%);
        transition: width 0.6s, height 0.6s;
    }
    
    .btn:active::before {
        width: 300px;
        height: 300px;
    }
    
    .btn-primary {
        background-color: var(--primary-color);
        color: white;
    }
    
    .btn-primary:hover {
        background-color: color-mix(in srgb, var(--primary-color) 85%, black);
    }
    
    /* CSS Grid Areas */
    .layout {
        display: grid;
        grid-template-areas:
            "header header header"
            "nav main aside"
            "footer footer footer";
        grid-template-columns: 200px 1fr 200px;
        grid-template-rows: auto 1fr auto;
        min-height: 100vh;
    }
    
    .header { grid-area: header; }
    .nav { grid-area: nav; }
    .main { grid-area: main; }
    .aside { grid-area: aside; }
    .footer { grid-area: footer; }
    
    /* Animation */
    @keyframes slide-in {
        from {
            transform: translateX(-100%);
            opacity: 0;
        }
        to {
            transform: translateX(0);
            opacity: 1;
        }
    }
    
    .animate-slide-in {
        animation: slide-in 0.5s ease-out forwards;
    }
    
    /* Media Queries with Container Queries */
    @container (min-width: 768px) {
        .card {
            flex-direction: row;
        }
    }
    
    @media (max-width: 768px) {
        .layout {
            grid-template-areas:
                "header"
                "nav"
                "main"
                "aside"
                "footer";
            grid-template-columns: 1fr;
        }
    }
    
    /* CSS Shapes */
    .circle-text {
        width: 200px;
        height: 200px;
        shape-outside: circle(50%);
        float: left;
        margin: 0 20px 20px 0;
    }
    
    /* Scroll Snap */
    .carousel {
        display: flex;
        overflow-x: auto;
        scroll-snap-type: x mandatory;
        scroll-behavior: smooth;
    }
    
    .carousel-item {
        flex: 0 0 100%;
        scroll-snap-align: start;
    }
    
    /* CSS Filters and Backdrop Filter */
    .glass {
        background: rgba(255, 255, 255, 0.1);
        backdrop-filter: blur(10px);
        border: 1px solid rgba(255, 255, 255, 0.2);
    }
    
    /* Aspect Ratio */
    .video-container {
        aspect-ratio: 16 / 9;
        width: 100%;
        background: #000;
    }
    
    /* Clamp for Responsive Typography */
    h1 {
        font-size: clamp(1.5rem, 4vw, 3rem);
        line-height: 1.2;
    }
    
    /* CSS Counters */
    .numbered-list {
        counter-reset: item;
    }
    
    .numbered-list li {
        counter-increment: item;
    }
    
    .numbered-list li::before {
        content: counter(item) ". ";
        font-weight: bold;
        color: var(--primary-color);
    }
    """
    
    private static let jsonSample = """
    {
      "name": "CodeEditor Sample Application",
      "version": "1.0.0",
      "description": "A sample application demonstrating JSON structure and various data types",
      "private": true,
      "main": "index.js",
      
      "__comments": {
        "todo": "Add more configuration options",
        "fixme": "Update deprecated dependencies"
      },
      
      "author": {
        "name": "John Doe",
        "email": "john.doe@example.com",
        "url": "https://example.com"
      },
      
      "contributors": [
        {
          "name": "Jane Smith",
          "email": "jane.smith@example.com"
        },
        {
          "name": "Bob Johnson",
          "email": "bob.johnson@example.com"
        }
      ],
      
      "scripts": {
        "start": "node index.js",
        "dev": "nodemon index.js",
        "test": "jest --coverage",
        "build": "webpack --mode production",
        "lint": "eslint . --ext .js,.jsx",
        "format": "prettier --write '**/*.{js,jsx,json,css,md}'"
      },
      
      "dependencies": {
        "express": "^4.18.2",
        "react": "^18.2.0",
        "react-dom": "^18.2.0",
        "axios": "^1.4.0",
        "lodash": "^4.17.21",
        "moment": "^2.29.4"
      },
      
      "devDependencies": {
        "@types/node": "^18.16.0",
        "@types/react": "^18.2.0",
        "eslint": "^8.40.0",
        "jest": "^29.5.0",
        "nodemon": "^2.0.22",
        "prettier": "^2.8.8",
        "webpack": "^5.82.0"
      },
      
      "config": {
        "port": 3000,
        "host": "localhost",
        "api": {
          "baseUrl": "https://api.example.com",
          "version": "v1",
          "timeout": 30000,
          "retries": 3
        },
        "features": {
          "authentication": true,
          "notifications": true,
          "darkMode": false,
          "analytics": {
            "enabled": true,
            "provider": "google",
            "trackingId": "UA-123456789-0"
          }
        }
      },
      
      "database": {
        "type": "postgresql",
        "host": "localhost",
        "port": 5432,
        "name": "myapp_db",
        "tables": ["users", "posts", "comments", "likes"]
      },
      
      "numbers": {
        "integer": 42,
        "float": 3.14159,
        "negative": -17,
        "exponential": 1.23e-4,
        "hex": "0xFF",
        "binary": "0b1010"
      },
      
      "arrays": {
        "simple": [1, 2, 3, 4, 5],
        "mixed": ["string", 123, true, null, {"nested": "object"}],
        "matrix": [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9]
        ]
      },
      
      "special": {
        "nullValue": null,
        "booleanTrue": true,
        "booleanFalse": false,
        "emptyString": "",
        "emptyArray": [],
        "emptyObject": {}
      },
      
      "unicode": {
        "emoji": "🚀 💻 ✨",
        "chinese": "你好世界",
        "arabic": "مرحبا بالعالم",
        "special": "\\u00A9 2024"
      }
    }
    """
    
    private static let markdownSample = """
    # Markdown Syntax Guide
    
    <!-- TODO: Add more examples for tables -->
    <!-- FIXME: Update broken links in references -->
    
    ## Table of Contents
    
    1. [Headers](#headers)
    2. [Emphasis](#emphasis)
    3. [Lists](#lists)
    4. [Links](#links)
    5. [Images](#images)
    6. [Code](#code)
    7. [Tables](#tables)
    8. [Blockquotes](#blockquotes)
    9. [Advanced Features](#advanced-features)
    
    ---
    
    ## Headers
    
    # H1 Header
    ## H2 Header
    ### H3 Header
    #### H4 Header
    ##### H5 Header
    ###### H6 Header
    
    Alternative H1
    ==============
    
    Alternative H2
    --------------
    
    ## Emphasis
    
    *Italic text* or _italic text_
    
    **Bold text** or __bold text__
    
    ***Bold and italic*** or ___bold and italic___
    
    ~~Strikethrough text~~
    
    ## Lists
    
    ### Unordered List
    
    * Item 1
    * Item 2
      * Nested item 2.1
      * Nested item 2.2
        * Deep nested item
    * Item 3
    
    ### Ordered List
    
    1. First item
    2. Second item
       1. Nested item 2.1
       2. Nested item 2.2
    3. Third item
    
    ### Task List
    
    - [x] Completed task
    - [ ] Incomplete task
    - [x] Another completed task
      - [ ] Nested incomplete task
      - [x] Nested complete task
    
    ## Links
    
    [Inline link](https://www.example.com)
    
    [Link with title](https://www.example.com "Example Website")
    
    [Reference link][reference]
    
    [Relative link](../README.md)
    
    Autolink: <https://www.example.com>
    
    Email: <email@example.com>
    
    ## Images
    
    ![Alt text](image.jpg)
    
    ![Alt text with title](image.jpg "Image Title")
    
    [![Clickable image](thumbnail.jpg)](https://www.example.com)
    
    ## Code
    
    ### Inline Code
    
    Use `inline code` for small code snippets.
    
    ### Code Blocks
    
    ```javascript
    // JavaScript code block
    function greet(name) {
        console.log(`Hello, ${name}!`);
    }
    
    greet('World');
    ```
    
    ```python
    # Python code block
    def greet(name):
        print(f"Hello, {name}!")
    
    greet("World")
    ```
    
    ### Indented Code Block
    
        // This is an indented code block
        function example() {
            return true;
        }
    
    ## Tables
    
    | Header 1 | Header 2 | Header 3 |
    |----------|:--------:|---------:|
    | Left     | Center   | Right    |
    | Cell 1   | Cell 2   | Cell 3   |
    | Long content | **Bold** | *Italic* |
    
    ## Blockquotes
    
    > This is a blockquote.
    > It can span multiple lines.
    
    > Nested blockquotes:
    >> This is nested
    >>> This is deeply nested
    
    > ### Blockquote with other elements
    > 
    > - List item 1
    > - List item 2
    > 
    > *Italic* and **bold** text in blockquote.
    
    ## Advanced Features
    
    ### Horizontal Rule
    
    ---
    
    ***
    
    ___
    
    ### Footnotes
    
    Here's a sentence with a footnote[^1].
    
    [^1]: This is the footnote text.
    
    ### Definition Lists
    
    Term 1
    :   Definition 1
    
    Term 2
    :   Definition 2a
    :   Definition 2b
    
    ### Abbreviations
    
    The HTML specification is maintained by the W3C.
    
    *[HTML]: HyperText Markup Language
    *[W3C]: World Wide Web Consortium
    
    ### HTML in Markdown
    
    <div style="background-color: #f0f0f0; padding: 10px;">
      This is a <strong>HTML</strong> block with <em>styling</em>.
    </div>
    
    ### Math (when supported)
    
    Inline math: $x = {-b \\pm \\sqrt{b^2-4ac} \\over 2a}$
    
    Block math:
    
    $$
    \\begin{aligned}
    \\nabla \\times \\vec{\\mathbf{B}} -\\, \\frac1c\\, \\frac{\\partial\\vec{\\mathbf{E}}}{\\partial t} & = \\frac{4\\pi}{c}\\vec{\\mathbf{j}} \\\\
    \\nabla \\cdot \\vec{\\mathbf{E}} & = 4 \\pi \\rho \\\\
    \\nabla \\times \\vec{\\mathbf{E}}\\, +\\, \\frac1c\\, \\frac{\\partial\\vec{\\mathbf{B}}}{\\partial t} & = \\vec{\\mathbf{0}} \\\\
    \\nabla \\cdot \\vec{\\mathbf{B}} & = 0
    \\end{aligned}
    $$
    
    ### Emoji (when supported)
    
    :smile: :heart: :thumbsup: :rocket: :octocat:
    
    ## References
    
    [reference]: https://www.reference-example.com "Reference Title"
    
    ---
    
    *Last updated: January 15, 2024*
    """
    
    private static let yamlSample = """
    # YAML Configuration Example
    # TODO: Add environment-specific configurations
    # FIXME: Validate schema for production deployment
    
    ---
    # Application Configuration
    app:
      name: CodeEditor Sample App
      version: 1.0.0
      description: A comprehensive YAML configuration example
      environment: development
      
    # Server Configuration
    server:
      host: localhost
      port: 3000
      protocol: https
      ssl:
        enabled: true
        cert: /path/to/cert.pem
        key: /path/to/key.pem
      
    # Database Configuration
    database:
      primary:
        type: postgresql
        host: db.example.com
        port: 5432
        name: myapp_production
        username: ${DB_USER}
        password: ${DB_PASSWORD}
        pool:
          min: 5
          max: 20
          idle: 10000
        options:
          encrypt: true
          trustServerCertificate: false
      
      replica:
        - host: replica1.example.com
          port: 5432
          weight: 1
        - host: replica2.example.com
          port: 5432
          weight: 2
    
    # Logging Configuration
    logging:
      level: info  # debug, info, warn, error
      format: json
      outputs:
        - type: console
          colorize: true
        - type: file
          path: /var/log/app.log
          maxSize: 10MB
          maxFiles: 5
          compress: true
        - type: syslog
          host: syslog.example.com
          port: 514
          protocol: udp
    
    # Features with Anchors and Aliases
    defaults: &defaults
      timeout: 30s
      retries: 3
      backoff: exponential
    
    # API Configuration
    api:
      <<: *defaults
      baseUrl: https://api.example.com
      version: v2
      endpoints:
        users:
          path: /users
          methods: [GET, POST, PUT, DELETE]
          rateLimit:
            requests: 100
            window: 1m
        posts:
          path: /posts
          methods: [GET, POST]
          cache:
            enabled: true
            ttl: 5m
    
    # Complex Data Structures
    services:
      - &auth_service
        name: authentication
        url: https://auth.example.com
        timeout: 10s
        healthCheck:
          endpoint: /health
          interval: 30s
          timeout: 5s
      
      - name: notification
        url: https://notify.example.com
        dependencies:
          - *auth_service
        config:
          providers:
            email:
              smtp:
                host: smtp.gmail.com
                port: 587
                secure: true
            push:
              fcm:
                serverKey: ${FCM_SERVER_KEY}
            sms:
              twilio:
                accountSid: ${TWILIO_ACCOUNT_SID}
                authToken: ${TWILIO_AUTH_TOKEN}
    
    # Multi-line Strings
    messages:
      welcome: |
        Welcome to our application!
        This is a multi-line message
        that preserves line breaks.
      
      compact: >
        This is a folded string that
        will be rendered as a single
        line without line breaks.
      
      literal: |+
        This string has trailing
        newlines preserved.
        
        
      stripped: |-
        This string has trailing
        newlines stripped.
    
    # Arrays and Objects
    users:
      - id: 1
        name: Alice
        roles: [admin, user]
        metadata:
          lastLogin: 2024-01-15T10:30:00Z
          preferences:
            theme: dark
            language: en
      
      - id: 2
        name: Bob
        roles: [user]
        active: true
    
    # Numeric Values
    numbers:
      integer: 42
      float: 3.14
      scientific: 1.23e-4
      octal: 0o755
      hex: 0xFF
      infinity: .inf
      not_a_number: .nan
    
    # Boolean Values
    booleans:
      - true
      - false
      - yes
      - no
      - on
      - off
    
    # Null Values
    nulls:
      - null
      - ~
      - 
    
    # Dates and Times
    dates:
      iso8601: 2024-01-15T10:30:00Z
      date: 2024-01-15
      timestamp: 1705318200
    
    # Tags and References
    development: &dev_config
      debug: true
      cache: false
      minify: false
    
    production: &prod_config
      debug: false
      cache: true
      minify: true
    
    environments:
      dev: *dev_config
      staging:
        <<: *dev_config
        cache: true  # Override specific value
      prod: *prod_config
    
    # Custom Types
    regex: !regexp '^[a-z]+$'
    function: !function 'Date.now'
    
    # Document End
    ...
    """
    
    private static let xmlSample = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!-- XML Document Example -->
    <!-- TODO: Add schema validation -->
    <!-- FIXME: Update deprecated namespace URIs -->
    
    <catalog xmlns="http://example.com/catalog"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://example.com/catalog catalog.xsd"
             version="1.0">
        
        <!-- Metadata -->
        <metadata>
            <title>Product Catalog</title>
            <description>A comprehensive product catalog example</description>
            <created>2024-01-15T10:30:00Z</created>
            <modified>2024-01-15T14:45:00Z</modified>
            <author>
                <name>John Doe</name>
                <email>john.doe@example.com</email>
            </author>
        </metadata>
        
        <!-- Categories -->
        <categories>
            <category id="electronics" name="Electronics">
                <description>Electronic devices and accessories</description>
                <subcategory id="computers" name="Computers"/>
                <subcategory id="phones" name="Phones"/>
                <subcategory id="accessories" name="Accessories"/>
            </category>
            <category id="books" name="Books">
                <description>Physical and digital books</description>
                <subcategory id="fiction" name="Fiction"/>
                <subcategory id="non-fiction" name="Non-Fiction"/>
            </category>
        </categories>
        
        <!-- Products -->
        <products>
            <product id="prod-001" category="electronics" subcategory="computers">
                <name>Laptop Pro 15"</name>
                <brand>TechCorp</brand>
                <model>LP-15-2024</model>
                <description>
                    <![CDATA[
                    High-performance laptop with:
                    • 15" Retina display
                    • Intel Core i7 processor
                    • 16GB RAM
                    • 512GB SSD
                    ]]>
                </description>
                <price currency="USD">1299.99</price>
                <discount type="percentage" validUntil="2024-02-01">10</discount>
                <stock>
                    <quantity>50</quantity>
                    <location warehouse="main">A-15-3</location>
                    <location warehouse="secondary">B-8-2</location>
                </stock>
                <specifications>
                    <spec name="processor" value="Intel Core i7-1260P"/>
                    <spec name="memory" value="16GB DDR5"/>
                    <spec name="storage" value="512GB NVMe SSD"/>
                    <spec name="display" value="15.6&quot; 2880x1800"/>
                    <spec name="weight" value="1.8kg"/>
                </specifications>
                <images>
                    <image type="main" src="laptop-main.jpg"/>
                    <image type="thumbnail" src="laptop-thumb.jpg"/>
                    <image type="gallery" src="laptop-1.jpg"/>
                    <image type="gallery" src="laptop-2.jpg"/>
                </images>
                <reviews count="127" average="4.5">
                    <review id="rev-001" rating="5" date="2024-01-10">
                        <author>Jane Smith</author>
                        <title>Excellent laptop!</title>
                        <comment>Fast, reliable, and great battery life.</comment>
                    </review>
                </reviews>
            </product>
            
            <product id="prod-002" category="books" subcategory="fiction">
                <name>The Digital Frontier</name>
                <author>Alice Johnson</author>
                <isbn>978-1-234-56789-0</isbn>
                <publisher>TechBooks Publishing</publisher>
                <publicationDate>2023-06-15</publicationDate>
                <description>A thrilling sci-fi novel about AI and humanity.</description>
                <price currency="USD">24.99</price>
                <formats>
                    <format type="hardcover" price="24.99"/>
                    <format type="paperback" price="14.99"/>
                    <format type="ebook" price="9.99"/>
                    <format type="audiobook" price="19.99"/>
                </formats>
                <languages>
                    <language code="en">English</language>
                    <language code="es">Spanish</language>
                    <language code="fr">French</language>
                </languages>
            </product>
        </products>
        
        <!-- Orders Example -->
        <orders>
            <order id="ord-001" status="shipped" date="2024-01-14T09:15:00Z">
                <customer id="cust-123">
                    <name>Robert Brown</name>
                    <email>robert.brown@example.com</email>
                    <address type="shipping">
                        <street>123 Main St</street>
                        <city>New York</city>
                        <state>NY</state>
                        <zip>10001</zip>
                        <country>USA</country>
                    </address>
                </customer>
                <items>
                    <item productId="prod-001" quantity="1" price="1169.99"/>
                    <item productId="prod-002" quantity="2" price="49.98"/>
                </items>
                <totals>
                    <subtotal>1219.97</subtotal>
                    <tax rate="8.875">108.27</tax>
                    <shipping method="express">15.00</shipping>
                    <total>1343.24</total>
                </totals>
            </order>
        </orders>
        
        <!-- Complex Nested Structure -->
        <configuration>
            <settings>
                <setting name="cache.enabled" value="true" type="boolean"/>
                <setting name="cache.ttl" value="3600" type="integer" unit="seconds"/>
                <setting name="api.key" value="${API_KEY}" type="string" encrypted="true"/>
            </settings>
            <features>
                <feature name="search" enabled="true">
                    <param name="fuzzy" value="true"/>
                    <param name="maxResults" value="100"/>
                </feature>
                <feature name="recommendations" enabled="false"/>
            </features>
        </configuration>
        
        <!-- Processing Instructions -->
        <?xml-stylesheet type="text/xsl" href="catalog.xsl"?>
        <?catalog-processor version="2.0" validate="true"?>
        
    </catalog>
    """
    
    private static let sqlSample = """
    -- SQL Comprehensive Example
    -- TODO: Add indexes for performance optimization
    -- FIXME: Update deprecated syntax for newer SQL versions
    
    -- Create database
    CREATE DATABASE IF NOT EXISTS ecommerce_db
        CHARACTER SET utf8mb4
        COLLATE utf8mb4_unicode_ci;
    
    USE ecommerce_db;
    
    -- Create tables with various constraints
    CREATE TABLE users (
        id INT PRIMARY KEY AUTO_INCREMENT,
        username VARCHAR(50) UNIQUE NOT NULL,
        email VARCHAR(100) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        first_name VARCHAR(50),
        last_name VARCHAR(50),
        date_of_birth DATE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        is_active BOOLEAN DEFAULT TRUE,
        role ENUM('admin', 'user', 'moderator') DEFAULT 'user',
        
        INDEX idx_email (email),
        INDEX idx_username (username),
        INDEX idx_created_at (created_at)
    ) ENGINE=InnoDB;
    
    -- Create products table
    CREATE TABLE products (
        id INT PRIMARY KEY AUTO_INCREMENT,
        sku VARCHAR(50) UNIQUE NOT NULL,
        name VARCHAR(200) NOT NULL,
        description TEXT,
        category_id INT,
        price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
        cost DECIMAL(10, 2),
        stock_quantity INT DEFAULT 0 CHECK (stock_quantity >= 0),
        is_available BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
        FULLTEXT(name, description)
    ) ENGINE=InnoDB;
    
    -- Create categories table
    CREATE TABLE categories (
        id INT PRIMARY KEY AUTO_INCREMENT,
        name VARCHAR(100) NOT NULL,
        parent_id INT,
        slug VARCHAR(100) UNIQUE NOT NULL,
        description TEXT,
        
        FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE CASCADE,
        INDEX idx_parent (parent_id)
    ) ENGINE=InnoDB;
    
    -- Create orders table
    CREATE TABLE orders (
        id INT PRIMARY KEY AUTO_INCREMENT,
        order_number VARCHAR(50) UNIQUE NOT NULL,
        user_id INT NOT NULL,
        status ENUM('pending', 'processing', 'shipped', 'delivered', 'cancelled') DEFAULT 'pending',
        total_amount DECIMAL(10, 2) NOT NULL,
        shipping_address JSON,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        shipped_at TIMESTAMP NULL,
        delivered_at TIMESTAMP NULL,
        
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
        INDEX idx_user_id (user_id),
        INDEX idx_status (status),
        INDEX idx_created_at (created_at)
    ) ENGINE=InnoDB;
    
    -- Create order items table
    CREATE TABLE order_items (
        id INT PRIMARY KEY AUTO_INCREMENT,
        order_id INT NOT NULL,
        product_id INT NOT NULL,
        quantity INT NOT NULL CHECK (quantity > 0),
        unit_price DECIMAL(10, 2) NOT NULL,
        discount_amount DECIMAL(10, 2) DEFAULT 0,
        
        FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT,
        INDEX idx_order_product (order_id, product_id)
    ) ENGINE=InnoDB;
    
    -- Create reviews table
    CREATE TABLE reviews (
        id INT PRIMARY KEY AUTO_INCREMENT,
        product_id INT NOT NULL,
        user_id INT NOT NULL,
        rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
        title VARCHAR(200),
        comment TEXT,
        is_verified_purchase BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        UNIQUE KEY unique_user_product (user_id, product_id),
        INDEX idx_product_rating (product_id, rating)
    ) ENGINE=InnoDB;
    
    -- Insert sample data
    INSERT INTO categories (name, slug, description) VALUES
        ('Electronics', 'electronics', 'Electronic devices and accessories'),
        ('Books', 'books', 'Physical and digital books'),
        ('Clothing', 'clothing', 'Apparel and fashion items');
    
    INSERT INTO users (username, email, password_hash, first_name, last_name, role) VALUES
        ('admin', 'admin@example.com', '$2y$10$YourHashHere', 'Admin', 'User', 'admin'),
        ('johndoe', 'john@example.com', '$2y$10$YourHashHere', 'John', 'Doe', 'user'),
        ('janedoe', 'jane@example.com', '$2y$10$YourHashHere', 'Jane', 'Doe', 'user');
    
    -- Complex queries examples
    
    -- 1. Get top-selling products with category info
    SELECT 
        p.id,
        p.name AS product_name,
        c.name AS category_name,
        COUNT(oi.id) AS times_ordered,
        SUM(oi.quantity) AS total_quantity_sold,
        SUM(oi.quantity * oi.unit_price) AS total_revenue
    FROM products p
    JOIN categories c ON p.category_id = c.id
    JOIN order_items oi ON p.id = oi.product_id
    JOIN orders o ON oi.order_id = o.id
    WHERE o.status IN ('shipped', 'delivered')
        AND o.created_at >= DATE_SUB(CURRENT_DATE, INTERVAL 30 DAY)
    GROUP BY p.id, p.name, c.name
    ORDER BY total_revenue DESC
    LIMIT 10;
    
    -- 2. User purchase history with window functions
    WITH user_orders AS (
        SELECT 
            u.id AS user_id,
            u.username,
            o.id AS order_id,
            o.total_amount,
            o.created_at,
            ROW_NUMBER() OVER (PARTITION BY u.id ORDER BY o.created_at DESC) AS order_rank,
            SUM(o.total_amount) OVER (PARTITION BY u.id ORDER BY o.created_at 
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
        FROM users u
        JOIN orders o ON u.id = o.user_id
        WHERE o.status != 'cancelled'
    )
    SELECT * FROM user_orders WHERE order_rank <= 5;
    
    -- 3. Product recommendations based on purchase patterns
    SELECT 
        p2.id,
        p2.name,
        COUNT(DISTINCT o1.user_id) AS co_purchase_count
    FROM order_items oi1
    JOIN order_items oi2 ON oi1.order_id = oi2.order_id AND oi1.product_id != oi2.product_id
    JOIN products p1 ON oi1.product_id = p1.id
    JOIN products p2 ON oi2.product_id = p2.id
    JOIN orders o1 ON oi1.order_id = o1.id
    WHERE p1.id = ? -- Input product ID
        AND o1.status IN ('shipped', 'delivered')
    GROUP BY p2.id, p2.name
    ORDER BY co_purchase_count DESC
    LIMIT 5;
    
    -- Stored procedure example
    DELIMITER //
    
    CREATE PROCEDURE UpdateProductStock(
        IN p_product_id INT,
        IN p_quantity_change INT,
        OUT p_new_stock INT
    )
    BEGIN
        DECLARE current_stock INT;
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            RESIGNAL;
        END;
        
        START TRANSACTION;
        
        SELECT stock_quantity INTO current_stock
        FROM products
        WHERE id = p_product_id
        FOR UPDATE;
        
        SET p_new_stock = current_stock + p_quantity_change;
        
        IF p_new_stock < 0 THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Insufficient stock';
        END IF;
        
        UPDATE products
        SET stock_quantity = p_new_stock
        WHERE id = p_product_id;
        
        COMMIT;
    END//
    
    DELIMITER ;
    
    -- Trigger example
    DELIMITER //
    
    CREATE TRIGGER update_product_availability
    AFTER UPDATE ON products
    FOR EACH ROW
    BEGIN
        IF NEW.stock_quantity = 0 AND OLD.stock_quantity > 0 THEN
            UPDATE products SET is_available = FALSE WHERE id = NEW.id;
        ELSEIF NEW.stock_quantity > 0 AND OLD.stock_quantity = 0 THEN
            UPDATE products SET is_available = TRUE WHERE id = NEW.id;
        END IF;
    END//
    
    DELIMITER ;
    
    -- View example
    CREATE VIEW product_sales_summary AS
    SELECT 
        p.id,
        p.name,
        p.price,
        COUNT(DISTINCT oi.order_id) AS order_count,
        SUM(oi.quantity) AS total_sold,
        AVG(r.rating) AS avg_rating,
        COUNT(DISTINCT r.id) AS review_count
    FROM products p
    LEFT JOIN order_items oi ON p.id = oi.product_id
    LEFT JOIN reviews r ON p.id = r.product_id
    GROUP BY p.id, p.name, p.price;
    
    -- Create indexes for optimization
    CREATE INDEX idx_orders_user_status ON orders(user_id, status);
    CREATE INDEX idx_products_category_available ON products(category_id, is_available);
    CREATE INDEX idx_reviews_product_created ON reviews(product_id, created_at);
    """
    
    private static let rubySample = """
    # Ruby comprehensive example
    
    # TODO: Add more metaprogramming examples
    # FIXME: Handle edge cases in concurrent code
    
    require 'json'
    require 'date'
    require 'net/http'
    require 'concurrent'
    
    # Module with mixins
    module Validatable
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      module ClassMethods
        def validates(attribute, options = {})
          @validations ||= {}
          @validations[attribute] = options
        end
        
        def validations
          @validations || {}
        end
      end
      
      def valid?
        self.class.validations.all? do |attr, options|
          value = send(attr)
          
          if options[:presence] && value.nil?
            false
          elsif options[:format] && !value.to_s.match?(options[:format])
            false
          elsif options[:length] && value.to_s.length < options[:length][:minimum]
            false
          else
            true
          end
        end
      end
    end
    
    # Class with various Ruby features
    class User
      include Validatable
      
      attr_accessor :name, :email, :age
      attr_reader :id, :created_at
      
      validates :name, presence: true, length: { minimum: 2 }
      validates :email, presence: true, format: /\\A[\\w+\\-.]+@[a-z\\d\\-]+(\\.[a-z\\d\\-]+)*\\.[a-z]+\\z/i
      
      @@user_count = 0
      
      def initialize(name:, email:, age: nil)
        @id = generate_id
        @name = name
        @email = email
        @age = age
        @created_at = Time.now
        @@user_count += 1
      end
      
      # Class method
      def self.user_count
        @@user_count
      end
      
      # Instance methods
      def adult?
        return false unless age
        age >= 18
      end
      
      def to_h
        {
          id: id,
          name: name,
          email: email,
          age: age,
          created_at: created_at.iso8601
        }
      end
      
      def to_json(*args)
        to_h.to_json(*args)
      end
      
      private
      
      def generate_id
        "usr_#{Time.now.to_i}_#{rand(1000)}"
      end
    end
    
    # Class with blocks and iterators
    class Collection
      include Enumerable
      
      def initialize
        @items = []
      end
      
      def <<(item)
        @items << item
        self
      end
      
      def each
        return enum_for(:each) unless block_given?
        @items.each { |item| yield item }
      end
      
      def select_by(&block)
        Collection.new.tap do |collection|
          each { |item| collection << item if block.call(item) }
        end
      end
    end
    
    # Metaprogramming example
    class DynamicClass
      def self.create_method(name, &block)
        define_method(name, &block)
      end
      
      def self.attr_with_history(*attrs)
        attrs.each do |attr|
          attr_reader attr
          
          define_method "#{attr}=" do |value|
            @history ||= {}
            @history[attr] ||= []
            @history[attr] << instance_variable_get("@#{attr}")
            instance_variable_set("@#{attr}", value)
          end
          
          define_method "#{attr}_history" do
            @history ||= {}
            @history[attr] || []
          end
        end
      end
      
      attr_with_history :value, :status
    end
    
    # Exception handling
    class CustomError < StandardError
      attr_reader :code
      
      def initialize(message, code = nil)
        super(message)
        @code = code
      end
    end
    
    # API Client with error handling
    class ApiClient
      BASE_URL = 'https://api.example.com'
      
      def initialize(api_key)
        @api_key = api_key
        @http = Net::HTTP.new(URI(BASE_URL).host, 443)
        @http.use_ssl = true
      end
      
      def get(endpoint)
        retries = 0
        begin
          response = @http.get(
            endpoint,
            'Authorization' => "Bearer #{@api_key}",
            'Content-Type' => 'application/json'
          )
          
          case response.code.to_i
          when 200..299
            JSON.parse(response.body, symbolize_names: true)
          when 401
            raise CustomError.new('Unauthorized', 401)
          when 404
            raise CustomError.new('Not found', 404)
          else
            raise CustomError.new("HTTP #{response.code}: #{response.message}", response.code.to_i)
          end
        rescue Net::ReadTimeout => e
          retries += 1
          retry if retries < 3
          raise CustomError.new('Request timeout', 504)
        end
      end
    end
    
    # Concurrent programming
    class AsyncProcessor
      def initialize(worker_count = 4)
        @pool = Concurrent::FixedThreadPool.new(worker_count)
        @results = Concurrent::Array.new
      end
      
      def process(items, &block)
        futures = items.map do |item|
          Concurrent::Future.execute(executor: @pool) do
            block.call(item)
          end
        end
        
        futures.map(&:value)
      ensure
        @pool.shutdown
        @pool.wait_for_termination
      end
    end
    
    # DSL example
    class ConfigDSL
      def initialize(&block)
        @config = {}
        instance_eval(&block) if block_given?
      end
      
      def method_missing(method, *args, &block)
        if block_given?
          @config[method] = ConfigDSL.new(&block).to_h
        elsif args.length == 1
          @config[method] = args.first
        else
          super
        end
      end
      
      def respond_to_missing?(method, include_private = false)
        true
      end
      
      def to_h
        @config
      end
    end
    
    # Usage examples
    if __FILE__ == $0
      # Create users
      users = Collection.new
      users << User.new(name: 'Alice', email: 'alice@example.com', age: 25)
      users << User.new(name: 'Bob', email: 'bob@example.com', age: 17)
      
      # Filter adults
      adults = users.select_by(&:adult?)
      
      puts "Total users: #{User.user_count}"
      puts "Adults: #{adults.count}"
      
      # DSL usage
      config = ConfigDSL.new do
        database do
          host 'localhost'
          port 5432
          name 'myapp'
          
          pool do
            size 10
            timeout 5000
          end
        end
        
        cache do
          enabled true
          ttl 3600
        end
      end
      
      puts "Config: #{config.to_h.inspect}"
      
      # Async processing
      processor = AsyncProcessor.new
      results = processor.process((1..10).to_a) do |n|
        sleep(0.1)  # Simulate work
        n * n
      end
      
      puts "Squared numbers: #{results.inspect}"
    end
    """
    
    private static let phpSample = """
    <?php
    // PHP comprehensive example
    
    // TODO: Implement PSR-4 autoloading
    // FIXME: Add proper error handling for database operations
    
    declare(strict_types=1);
    
    namespace App\\Examples;
    
    use DateTime;
    use DateTimeInterface;
    use JsonSerializable;
    use InvalidArgumentException;
    use PDO;
    use PDOException;
    
    // Traits
    trait TimestampableTrait 
    {
        protected ?DateTime $createdAt = null;
        protected ?DateTime $updatedAt = null;
        
        public function setCreatedAt(DateTime $createdAt): void 
        {
            $this->createdAt = $createdAt;
        }
        
        public function getCreatedAt(): ?DateTime 
        {
            return $this->createdAt;
        }
        
        public function setUpdatedAt(DateTime $updatedAt): void 
        {
            $this->updatedAt = $updatedAt;
        }
        
        public function getUpdatedAt(): ?DateTime 
        {
            return $this->updatedAt;
        }
    }
    
    // Interface
    interface RepositoryInterface 
    {
        public function find(int $id): ?object;
        public function findAll(): array;
        public function save(object $entity): void;
        public function delete(int $id): void;
    }
    
    // Abstract class
    abstract class Entity implements JsonSerializable 
    {
        use TimestampableTrait;
        
        protected ?int $id = null;
        
        public function getId(): ?int 
        {
            return $this->id;
        }
        
        public function setId(int $id): void 
        {
            $this->id = $id;
        }
        
        abstract public function validate(): bool;
    }
    
    // User entity
    class User extends Entity 
    {
        private string $username;
        private string $email;
        private string $passwordHash;
        private array $roles = ['user'];
        
        public function __construct(
            string $username,
            string $email,
            string $password
        ) {
            $this->username = $username;
            $this->email = $email;
            $this->passwordHash = password_hash($password, PASSWORD_BCRYPT);
            $this->createdAt = new DateTime();
            $this->updatedAt = new DateTime();
        }
        
        // Getters and setters with type declarations
        public function getUsername(): string 
        {
            return $this->username;
        }
        
        public function setUsername(string $username): void 
        {
            $this->username = $username;
            $this->updatedAt = new DateTime();
        }
        
        public function getEmail(): string 
        {
            return $this->email;
        }
        
        public function setEmail(string $email): void 
        {
            if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
                throw new InvalidArgumentException('Invalid email address');
            }
            $this->email = $email;
            $this->updatedAt = new DateTime();
        }
        
        public function verifyPassword(string $password): bool 
        {
            return password_verify($password, $this->passwordHash);
        }
        
        public function hasRole(string $role): bool 
        {
            return in_array($role, $this->roles, true);
        }
        
        public function addRole(string $role): void 
        {
            if (!in_array($role, $this->roles, true)) {
                $this->roles[] = $role;
            }
        }
        
        public function validate(): bool 
        {
            return !empty($this->username) 
                && !empty($this->email) 
                && filter_var($this->email, FILTER_VALIDATE_EMAIL);
        }
        
        public function jsonSerialize(): array 
        {
            return [
                'id' => $this->id,
                'username' => $this->username,
                'email' => $this->email,
                'roles' => $this->roles,
                'createdAt' => $this->createdAt?->format(DateTimeInterface::ISO8601),
                'updatedAt' => $this->updatedAt?->format(DateTimeInterface::ISO8601),
            ];
        }
    }
    
    // Repository pattern
    class UserRepository implements RepositoryInterface 
    {
        private PDO $db;
        
        public function __construct(PDO $db) 
        {
            $this->db = $db;
        }
        
        public function find(int $id): ?User 
        {
            $stmt = $this->db->prepare('
                SELECT * FROM users WHERE id = :id
            ');
            $stmt->execute(['id' => $id]);
            $data = $stmt->fetch(PDO::FETCH_ASSOC);
            
            return $data ? $this->hydrate($data) : null;
        }
        
        public function findByEmail(string $email): ?User 
        {
            $stmt = $this->db->prepare('
                SELECT * FROM users WHERE email = :email
            ');
            $stmt->execute(['email' => $email]);
            $data = $stmt->fetch(PDO::FETCH_ASSOC);
            
            return $data ? $this->hydrate($data) : null;
        }
        
        public function findAll(): array 
        {
            $stmt = $this->db->query('SELECT * FROM users ORDER BY created_at DESC');
            $users = [];
            
            while ($data = $stmt->fetch(PDO::FETCH_ASSOC)) {
                $users[] = $this->hydrate($data);
            }
            
            return $users;
        }
        
        public function save(object $entity): void 
        {
            if (!$entity instanceof User) {
                throw new InvalidArgumentException('Entity must be a User');
            }
            
            if ($entity->getId() === null) {
                $this->insert($entity);
            } else {
                $this->update($entity);
            }
        }
        
        public function delete(int $id): void 
        {
            $stmt = $this->db->prepare('DELETE FROM users WHERE id = :id');
            $stmt->execute(['id' => $id]);
        }
        
        private function insert(User $user): void 
        {
            $stmt = $this->db->prepare('
                INSERT INTO users (username, email, password_hash, roles, created_at, updated_at)
                VALUES (:username, :email, :password_hash, :roles, :created_at, :updated_at)
            ');
            
            $stmt->execute([
                'username' => $user->getUsername(),
                'email' => $user->getEmail(),
                'password_hash' => $user->passwordHash,
                'roles' => json_encode($user->roles),
                'created_at' => $user->getCreatedAt()?->format('Y-m-d H:i:s'),
                'updated_at' => $user->getUpdatedAt()?->format('Y-m-d H:i:s'),
            ]);
            
            $user->setId((int) $this->db->lastInsertId());
        }
        
        private function update(User $user): void 
        {
            $stmt = $this->db->prepare('
                UPDATE users 
                SET username = :username, 
                    email = :email, 
                    roles = :roles, 
                    updated_at = :updated_at
                WHERE id = :id
            ');
            
            $stmt->execute([
                'id' => $user->getId(),
                'username' => $user->getUsername(),
                'email' => $user->getEmail(),
                'roles' => json_encode($user->roles),
                'updated_at' => $user->getUpdatedAt()?->format('Y-m-d H:i:s'),
            ]);
        }
        
        private function hydrate(array $data): User 
        {
            $user = new User($data['username'], $data['email'], '');
            $user->setId((int) $data['id']);
            $user->passwordHash = $data['password_hash'];
            $user->roles = json_decode($data['roles'], true) ?: ['user'];
            
            if ($data['created_at']) {
                $user->setCreatedAt(new DateTime($data['created_at']));
            }
            if ($data['updated_at']) {
                $user->setUpdatedAt(new DateTime($data['updated_at']));
            }
            
            return $user;
        }
    }
    
    // Service class with dependency injection
    class AuthenticationService 
    {
        private UserRepository $userRepository;
        private array $config;
        
        public function __construct(UserRepository $userRepository, array $config = []) 
        {
            $this->userRepository = $userRepository;
            $this->config = array_merge([
                'session_lifetime' => 3600,
                'remember_lifetime' => 2592000, // 30 days
            ], $config);
        }
        
        public function login(string $email, string $password, bool $remember = false): ?User 
        {
            $user = $this->userRepository->findByEmail($email);
            
            if ($user === null || !$user->verifyPassword($password)) {
                return null;
            }
            
            $this->createSession($user, $remember);
            
            return $user;
        }
        
        public function logout(): void 
        {
            if (session_status() === PHP_SESSION_ACTIVE) {
                session_destroy();
            }
            
            if (isset($_COOKIE['remember_token'])) {
                setcookie('remember_token', '', time() - 3600, '/');
            }
        }
        
        private function createSession(User $user, bool $remember): void 
        {
            if (session_status() !== PHP_SESSION_ACTIVE) {
                session_start();
            }
            
            $_SESSION['user_id'] = $user->getId();
            $_SESSION['user_roles'] = $user->roles;
            $_SESSION['login_time'] = time();
            
            if ($remember) {
                $token = bin2hex(random_bytes(32));
                setcookie(
                    'remember_token',
                    $token,
                    time() + $this->config['remember_lifetime'],
                    '/',
                    '',
                    true,
                    true
                );
                // Store token in database (implementation omitted)
            }
        }
    }
    
    // Generator example
    function readLargeFile(string $filename): Generator 
    {
        $handle = fopen($filename, 'r');
        
        if (!$handle) {
            throw new InvalidArgumentException("Cannot open file: $filename");
        }
        
        try {
            while (!feof($handle)) {
                yield fgets($handle);
            }
        } finally {
            fclose($handle);
        }
    }
    
    // Anonymous class example
    $logger = new class {
        public function log(string $level, string $message): void 
        {
            echo sprintf("[%s] %s: %s\n", date('Y-m-d H:i:s'), strtoupper($level), $message);
        }
    };
    
    // Usage example
    try {
        // Database connection
        $db = new PDO('mysql:host=localhost;dbname=test', 'user', 'password', [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);
        
        // Create repository and service
        $userRepository = new UserRepository($db);
        $authService = new AuthenticationService($userRepository);
        
        // Create a new user
        $user = new User('johndoe', 'john@example.com', 'secret123');
        
        if ($user->validate()) {
            $userRepository->save($user);
            $logger->log('info', 'User created: ' . $user->getUsername());
        }
        
        // Login
        $loggedInUser = $authService->login('john@example.com', 'secret123', true);
        
        if ($loggedInUser) {
            $logger->log('info', 'User logged in: ' . $loggedInUser->getUsername());
            echo json_encode($loggedInUser, JSON_PRETTY_PRINT);
        }
        
    } catch (PDOException $e) {
        $logger->log('error', 'Database error: ' . $e->getMessage());
    } catch (Exception $e) {
        $logger->log('error', 'Error: ' . $e->getMessage());
    }
    """
}
