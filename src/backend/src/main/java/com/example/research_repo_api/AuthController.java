package com.example.research_repo_api;

import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import jakarta.servlet.http.HttpServletRequest;

/** POST /api/auth/login, POST /api/auth/logout, GET /api/auth/me */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    public record LoginRequest(String username, String password) {}

    private final AuthService auth;

    public AuthController(AuthService auth) {
        this.auth = auth;
    }

    @PostMapping("/login")
    public Map<String, Object> login(@RequestBody(required = false) LoginRequest body) {
        if (body == null) throw new BadRequestException("request body is required");
        return auth.login(body.username(), body.password());
    }

    @PostMapping("/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logout(HttpServletRequest request) {
        auth.requireUser(request);
        auth.logout(request);
    }

    @GetMapping("/me")
    public AuthService.SessionUser me(HttpServletRequest request) {
        return auth.requireUser(request);
    }
}
