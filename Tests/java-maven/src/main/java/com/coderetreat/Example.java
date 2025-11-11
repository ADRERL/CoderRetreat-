package com.coderetreat;

public class Example {
    
    public String greet(String name) {
        if (name == null || name.isEmpty()) {
            return "Hello, World!";
        }
        return "Hello, " + name + "!";
    }
    
    public int add(int a, int b) {
        return a + b;
    }
}
