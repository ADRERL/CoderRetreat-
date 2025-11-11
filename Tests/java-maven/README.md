# Code Retreat Java Maven

Maven-based Java project for Code Retreat coding challenges.

## Prerequisites

- Java 17 or higher
- Maven 3.6+

## Project Structure

```
java-maven/
├── pom.xml                    # Maven configuration
├── src/
│   ├── main/
│   │   └── java/
│   │       └── com/coderetreat/
│   │           └── Example.java
│   └── test/
│       └── java/
│           └── com/coderetreat/
│               └── ExampleTest.java
└── README.md
```

## Running Tests

```bash
# Run all tests
mvn test

# Run tests in watch mode (continuous)
mvn test -Dsurefire.rerunFailingTestsCount=1

# Run specific test class
mvn test -Dtest=ExampleTest

# Run with verbose output
mvn test -X

# Clean and test
mvn clean test
```

## Building

```bash
# Compile the project
mvn compile

# Package as JAR
mvn package

# Clean build artifacts
mvn clean
```

## Dependencies

- **JUnit 5** - Testing framework
- **AssertJ** - Fluent assertions library
- **Mockito** - Mocking framework

## Getting Started

1. Delete the example files when you're ready to start your challenge
2. Create your own classes in `src/main/java/com/coderetreat/`
3. Create corresponding tests in `src/test/java/com/coderetreat/`
4. Run `mvn test` to execute your tests

Happy coding!
