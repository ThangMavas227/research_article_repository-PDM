package com.example.research_repo_api;

import org.springframework.http.HttpStatus;

/** An error with an HTTP status; the handler turns it into {"error": "..."}. */
public class ApiException extends RuntimeException {
    private final HttpStatus status;

    public ApiException(HttpStatus status, String message) {
        super(message);
        this.status = status;
    }

    public HttpStatus status() {
        return status;
    }
}
