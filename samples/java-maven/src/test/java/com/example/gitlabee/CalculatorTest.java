package com.example.gitlabee;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.Test;

class CalculatorTest {
    private final Calculator calculator = new Calculator();

    @Test
    void addsNumbers() {
        assertEquals(5, calculator.add(2, 3));
    }

    @Test
    void rejectsZeroDivisor() {
        assertThrows(IllegalArgumentException.class, () -> calculator.divide(10, 0));
    }

    @Test
    void normalizesNames() {
        assertEquals("gitlab", calculator.normalizeName(" GitLab "));
    }
}
