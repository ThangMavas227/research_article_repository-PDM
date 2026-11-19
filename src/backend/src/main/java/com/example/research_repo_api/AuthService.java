package com.example.research_repo_api;

import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;

import jakarta.servlet.http.HttpServletRequest;

/**
 * Login sessions. After a successful login the server returns a random token; the client sends it back
 * in the header "Authorization: Bearer <token>". Tokens live in memory (restarting the API logs everyone
 * out) and expire after 8 hours. Passwords are checked here against the bcrypt hash in User.PasswordHash.
 */
@Service
public class AuthService {

    public record SessionUser(String id, String username, String role) {}

    private record Session(SessionUser user, Instant expires) {}

    private static final long TTL_SECONDS = 8 * 3600;

    private final JdbcTemplate jdbc;
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();
    private final SecureRandom random = new SecureRandom();
    private final Map<String, Session> sessions = new ConcurrentHashMap<>();

    public AuthService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Returns {token, user} or throws 401. */
    public Map<String, Object> login(String username, String password) {
        if (username == null || username.isBlank() || password == null || password.isEmpty()) {
            throw new BadRequestException("username and password are required");
        }
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT UserID, Username, PasswordHash, Role FROM User WHERE Username = ?", username.trim());
        if (rows.isEmpty() || !encoder.matches(password, (String) rows.get(0).get("PasswordHash"))) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "invalid username or password");
        }
        Map<String, Object> r = rows.get(0);
        SessionUser user = new SessionUser((String) r.get("UserID"), (String) r.get("Username"), (String) r.get("Role"));
        byte[] bytes = new byte[32];
        random.nextBytes(bytes);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        sessions.put(token, new Session(user, Instant.now().plusSeconds(TTL_SECONDS)));
        return Map.of("token", token, "user", user);
    }

    public void logout(HttpServletRequest request) {
        String token = tokenOf(request);
        if (token != null) sessions.remove(token);
    }

    /** The logged-in user, or 401 when the token is missing, unknown or expired. */
    public SessionUser requireUser(HttpServletRequest request) {
        String token = tokenOf(request);
        Session s = token == null ? null : sessions.get(token);
        if (s == null || s.expires().isBefore(Instant.now())) {
            if (token != null) sessions.remove(token);
            throw new ApiException(HttpStatus.UNAUTHORIZED, "login required");
        }
        return s.user();
    }

    /** 401 when not logged in, 403 when logged in but not an admin. */
    public SessionUser requireAdmin(HttpServletRequest request) {
        SessionUser u = requireUser(request);
        if (!"admin".equals(u.role())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "admin role required");
        }
        return u;
    }

    private static String tokenOf(HttpServletRequest request) {
        String h = request.getHeader("Authorization");
        if (h == null || !h.regionMatches(true, 0, "Bearer ", 0, 7)) return null;
        String t = h.substring(7).trim();
        return t.isEmpty() ? null : t;
    }
}
