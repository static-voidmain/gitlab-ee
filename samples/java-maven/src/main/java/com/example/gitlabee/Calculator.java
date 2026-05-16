package com.example.gitlabee;

import java.util.Objects;

public final class Calculator {
    public int add(final int left, final int right) {
        return left + right;
    }

    public int divide(final int dividend, final int divisor) {
        if (divisor == 0) {
            throw new IllegalArgumentException("divisor must not be zero");
        }
        return dividend / divisor;
    }

    public String normalizeName(final String value) {
        return Objects.requireNonNull(value, "value must not be null").trim().toLowerCase();
    }
}
