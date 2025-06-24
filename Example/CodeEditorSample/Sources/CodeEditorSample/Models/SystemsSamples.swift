import Foundation

// MARK: - Systems Programming Samples

enum SystemsSamples {

    // MARK: - Go Sample

    static let goSample = """
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

    // MARK: - Rust Sample

    static let rustSample = """
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

    // MARK: - C++ Sample

    static let cppSample = """
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
}
