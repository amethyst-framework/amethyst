# Amethyst Web Framework

A modern, user-friendly web framework for [Crystal](https://crystal-lang.org/) with enterprise-grade features and zero boilerplate configuration.

## Why Amethyst?

Amethyst provides a **modern builder pattern** with **environment-aware defaults** and **fluent configuration** for building web applications with clean, readable code.

### Modern Architecture

```crystal
# Clean and readable configuration
app = Amethyst::Application.new("production")
  .security { |s| s.csrf(enabled: true, secret_key: "secret") }
```

### Key Benefits

- **Simple & Clean**: Fluent builder pattern with minimal configuration
- **Environment-Aware**: Automatic configuration based on environment (development/production/test)
- **Type-Safe**: All configuration options are compile-time validated
- **Discoverable**: Clear method names organized by feature area
- **Flexible**: Can use pre-built environment configs or customize any setting
- **Maintainable**: Configuration is centralized and organized

## Quick Start

### Simple Web Application

```crystal
require "amethyst"

# Create and configure your application
app = Amethyst::Application.new("development")
  .get("/", "HomeController", "index")
  .get("/users/:id", "UsersController", "show")
  .resource("users")  # Creates RESTful routes

# Start the server
app.serve(3000)
```

### Production Application

```crystal
require "amethyst"

app = Amethyst::Application.new("production")
  .security do |security|
    security
      .csrf(enabled: true, secret_key: ENV["CSRF_SECRET"])
      .xss_protection(enabled: true, frame_options: "SAMEORIGIN")
      .rate_limiting(enabled: true, requests_per_minute: 100)
      .secure_headers(force_https: true, hsts_max_age: 31536000)
      .jwt_authentication(
        enabled: true, 
        secret_key: ENV["JWT_SECRET"], 
        expiration_time: 1.hour
      )
  end
  .performance do |perf|
    perf
      .caching(enabled: true, size_mb: 256, default_ttl: 5.minutes)
      .static_files(gzip: true, zero_copy: true)
      .connection_pooling(max_connections: 25, timeout: 30.seconds)
      .http2(enabled: true, server_push: true)
      .routing(compiled: true, caching: true)
  end
  .observability do |obs|
    obs
      .structured_logging(level: "info", format: "json")
      .distributed_tracing(
        enabled: true, 
        service_name: "my-api", 
        endpoint: ENV["JAEGER_ENDPOINT"]
      )
      .metrics(enabled: true, endpoint: "/metrics")
      .health_checks(enabled: true, timeout: 5.seconds)
      .error_reporting(enabled: true, sampling_rate: 0.1)
  end
  .realtime do |rt|
    rt
      .websockets(enabled: true, max_connections: 1000)
      .server_sent_events(enabled: true, history_size: 100)
      .authentication(enabled: true)
      .rate_limiting(enabled: true, max_connections_per_ip: 10)
  end

# Add routes
app
  .get("/", "HomeController", "index")
  .resource("users")
  .resource("posts")
  .websocket("/ws", ChatController)
  .server_sent_events("/events", NotificationController)
  .serve(ENV["PORT"]?.try(&.to_i) || 3000)
```

## Installation

```bash
# Add to shard.yml
dependencies:
  amethyst:
    github: amethyst-framework/amethyst
    version: ~> 0.8.0

shards install
```

## Core Features

### Configuration System

Amethyst uses organized configuration objects with fluent methods:

**Security Configuration:**
```crystal
app.security do |security|
  security
    .csrf(enabled: true, secret_key: "your-secret")
    .xss_protection(enabled: true, auto_escape_html: true)
    .rate_limiting(enabled: true, requests_per_minute: 200)
    .secure_headers(enabled: true, force_https: true)
    .jwt_authentication(enabled: true, secret_key: ENV["JWT_SECRET"])
end
```

**Performance Configuration:**
```crystal
app.performance do |perf|
  perf
    .caching(enabled: true, size_mb: 128, default_ttl: 5.minutes)
    .static_files(gzip: true, zero_copy: true)
    .connection_pooling(max_connections: 25)
    .http2(enabled: true, server_push: true)
    .routing(compiled: true, caching: true)
end
```

**Observability Configuration:**
```crystal
app.observability do |obs|
  obs
    .structured_logging(level: "info", format: "json")
    .distributed_tracing(enabled: true, service_name: "my-service")
    .metrics(enabled: true, endpoint: "/metrics")
    .health_checks(enabled: true, detailed: true)
    .error_reporting(enabled: true, sampling_rate: 1.0)
end
```

**Realtime Configuration:**
```crystal
app.realtime do |rt|
  rt
    .websockets(enabled: true, max_connections: 1000)
    .server_sent_events(enabled: true, history_size: 100)
    .authentication(enabled: true, token_header: "Authorization")
    .rate_limiting(enabled: true, max_messages_per_minute: 60)
end
```

### Environment-Aware Defaults

The framework automatically configures based on environment:

```crystal
# Development - relaxed security, detailed logging
app = Amethyst::Application.new("development")

# Production - full security, optimized performance  
app = Amethyst::Application.new("production")

# Test - minimal overhead
app = Amethyst::Application.new("test")
```

### Method Chaining

Everything is chainable for maximum readability:

```crystal
app = Amethyst::Application.new("production")
  .security { |s| s.csrf(enabled: true).rate_limiting(enabled: true) }
  .performance { |p| p.caching(enabled: true).http2(enabled: true) }
  .observability { |o| o.structured_logging(level: "info") }
  .get("/", "HomeController", "index")
  .get("/health", "HealthController", "check")
  .serve(3000)
```

### Built-in Features

**Security (Built-in):**
- CSRF Protection with double-submit cookies
- XSS Prevention with HTML sanitization
- SQL Injection Protection
- Rate Limiting with multiple algorithms
- JWT Authentication with refresh tokens
- Secure Headers (HSTS, CSP, X-Frame-Options, etc.)

**Performance:**
- Radix Tree Routing (O(log n) lookup)
- Zero-Copy File Serving using sendfile
- Connection Pooling with health checks
- HTTP/2 Support with server push
- Multi-strategy Caching (Memory, LRU, Redis)

**Real-time:**
- WebSockets with connection management
- Server-Sent Events with history replay
- Broadcasting and channel support
- Authentication and rate limiting

**Observability:**
- Structured Logging with correlation IDs
- Distributed Tracing (OpenTelemetry/Jaeger)
- Health Checks for databases, Redis, HTTP endpoints
- Metrics Collection (Prometheus-compatible)
- Graceful Shutdown with request draining

## Examples

### API Server

```crystal
app = Amethyst::Application.new("production")
  .security { |s| s.jwt_authentication(enabled: true, secret_key: ENV["JWT_SECRET"]) }
  .performance { |p| p.caching(enabled: true).connection_pooling(max_connections: 50) }
  .observability { |o| o.structured_logging(level: "info").metrics(enabled: true) }

# API routes
app
  .post("/api/auth/login", "AuthController", "login")
  .get("/api/users", "UsersController", "index")
  .get("/api/users/:id", "UsersController", "show")
  .post("/api/users", "UsersController", "create")
  .serve(8080)
```

### Chat Application

```crystal
app = Amethyst::Application.new("production")
  .security { |s| s.csrf(enabled: true).rate_limiting(enabled: true) }
  .realtime do |rt|
    rt.websockets(enabled: true, compression: true)
      .authentication(enabled: true)
      .rate_limiting(enabled: true, max_messages_per_minute: 60)
  end

app
  .get("/", "ChatController", "index") 
  .websocket("/chat", ChatWebSocketController)
  .serve(3000)
```

### Microservice

```crystal
app = Amethyst::Application.new("production")
  .observability do |obs|
    obs
      .structured_logging(level: "info", format: "json")
      .distributed_tracing(enabled: true, service_name: "user-service")
      .metrics(enabled: true, collect_http: true)
      .health_checks(enabled: true, dependencies: ["database", "redis"])
  end

app
  .get("/health", "HealthController", "check")
  .get("/metrics", "MetricsController", "show")
  .resource("users")
  .serve(8080)
```

## Testing

The framework includes a comprehensive test suite:

```bash
# Run all tests
crystal spec

# Run specific feature tests
crystal spec spec/config/       # Configuration system
crystal spec spec/application/  # Application builder
crystal spec spec/basic_spec.cr # Integration tests

# Development workflow
crystal spec --watch     # Auto-run tests on changes
crystal spec --verbose   # Detailed output
```

The tests validate:
- **Configuration System**: All fluent configuration methods
- **Environment Awareness**: Development, production, test presets
- **Method Chaining**: Fluent interface across all areas
- **Type Safety**: Compile-time validation
- **Architecture Design**: Builder pattern implementation

## Development

### Project Structure

```
amethyst/
├── src/
│   ├── amethyst.cr              # Framework entry point
│   ├── amethyst/
│   │   ├── application.cr       # Modern application builder
│   │   ├── config/              # Configuration objects
│   │   │   ├── security_config.cr
│   │   │   ├── performance_config.cr
│   │   │   ├── observability_config.cr
│   │   │   └── realtime_config.cr
│   │   ├── base/               # Core application classes
│   │   ├── routing/            # Radix tree routing
│   │   ├── security/           # Security middleware
│   │   ├── observability/     # Logging, tracing, metrics
│   │   ├── websocket/          # WebSocket support
│   │   ├── sse/               # Server-Sent Events
│   │   └── middleware/        # Middleware stack
├── spec/                       # Comprehensive test suite
├── EXAMPLES.md                 # Detailed usage examples
└── README.md                   # This file
```

### Running Your Application

```bash
# Development with hot reload
crystal run src/app.cr

# Production build
crystal build --release src/app.cr -o bin/app

# With environment
AMETHYST_ENV=production ./bin/app
```

## Contributing

1. **Fork the repository** and create your feature branch
2. **Write comprehensive tests** for your changes
3. **Ensure all tests pass**: `crystal spec`
4. **Format code**: `crystal tool format`
5. **Open a Pull Request** with clear description

### Development Setup

```bash
git clone https://github.com/amethyst-framework/amethyst.git
cd amethyst
shards install
crystal spec  # Ensure everything works
```

## Why Choose Amethyst?

### **Developer Experience**
- **Simple Configuration**: Fluent builder pattern with clear method names
- **Environment Aware**: Sensible defaults for development, production, and testing
- **Type Safe**: Compile-time validation with excellent IDE support
- **Self-Documenting**: Clear method names organized by feature area

### **Production Ready**
- **Security by Default**: CSRF, XSS, rate limiting, secure headers built-in
- **Performance Optimized**: Radix tree routing, zero-copy files, HTTP/2
- **Observable**: Structured logging, distributed tracing, health checks
- **Scalable**: WebSocket/SSE support, connection pooling, graceful shutdown

### **Modern Architecture**
- **Builder Pattern**: Fluent, chainable configuration
- **Separation of Concerns**: Features organized by domain
- **Maintainable**: Easy to add features without breaking existing code
- **Flexible**: Use defaults or customize everything

## License

MIT License - see the [LICENSE](LICENSE) file for details.

## Community

- **GitHub Issues**: [Report bugs and request features](https://github.com/amethyst-framework/amethyst/issues)
- **Discussions**: [Ask questions and share ideas](https://github.com/amethyst-framework/amethyst/discussions)
- **Crystal Community**: [Join the Crystal community](https://crystal-lang.org/community/)