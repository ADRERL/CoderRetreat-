package com.coderetreat;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

import static org.assertj.core.assertions.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.*;

class ExampleTest {

    @Test
    @DisplayName("Should greet with name")
    void shouldGreetWithName() {
        Example example = new Example();
        String result = example.greet("CodeRetreat");
        
        assertThat(result).isEqualTo("Hello, CodeRetreat!");
    }

    @Test
    @DisplayName("Should greet world when name is null")
    void shouldGreetWorldWhenNameIsNull() {
        Example example = new Example();
        String result = example.greet(null);
        
        assertThat(result).isEqualTo("Hello, World!");
    }

    @Test
    @DisplayName("Should greet world when name is empty")
    void shouldGreetWorldWhenNameIsEmpty() {
        Example example = new Example();
        String result = example.greet("");
        
        assertThat(result).isEqualTo("Hello, World!");
    }

    @ParameterizedTest
    @CsvSource({
        "1, 2, 3",
        "0, 0, 0",
        "-1, 1, 0",
        "100, 200, 300"
    })
    @DisplayName("Should add two numbers correctly")
    void shouldAddTwoNumbers(int a, int b, int expected) {
        Example example = new Example();
        int result = example.add(a, b);
        
        assertThat(result).isEqualTo(expected);
    }
}
