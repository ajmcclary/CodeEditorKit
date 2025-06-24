import Foundation

// MARK: - Web Development Samples

enum WebSamples {
    // MARK: - JavaScript Sample

    static let javascriptSample = """
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

    static let typescriptSample = """
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

    // MARK: - HTML Sample

    static let htmlSample = """
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

    // MARK: - CSS Sample

    static let cssSample = """
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
}
