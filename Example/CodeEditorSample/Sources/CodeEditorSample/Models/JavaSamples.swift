import Foundation

// MARK: - Java Samples

enum JavaSamples {
    static let javaSample = """
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
}
