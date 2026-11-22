package com.example.research_repo_api;

/** Thrown for invalid request parameters; mapped to HTTP 400. */
public class BadRequestException extends RuntimeException {
    public BadRequestException(String message) {
        super(message);
    }
}
