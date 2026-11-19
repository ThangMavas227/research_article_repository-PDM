
"use strict";
const API_BASE_URL = window.APP_CONFIG?.AUTH_BASE_URL||"http://localhost:8080";
// DOM Elements
const form = document.getElementById("login-form");
const usernameInput = document.getElementById("username");
const passwordInput = document.getElementById("password");

const usernameError = document.getElementById("username-error");
const passwordError = document.getElementById("password-error");
const formMessage = document.getElementById("form-message");
const loginButton = document.getElementById("login-button");

const togglePassword = document.getElementById("toggle-password");
const togglePasswordIconPath = document.getElementById(
    "toggle-password-icon-path"
);
const togglePasswordIconCircle = document.getElementById(
    "toggle-password-icon-circle"
);

// Display Validation Error
function setError(input, errorElement, message) {
    errorElement.textContent = message;

    if (message) {
        input.setAttribute("aria-invalid", "true");
    } else {
        input.removeAttribute("aria-invalid");
    }
}

// Validate Login Form
function validateForm() {
    let isValid = true;

    const username = usernameInput.value.trim();
    const password = passwordInput.value;

    setError(usernameInput, usernameError, "");
    setError(passwordInput, passwordError, "");

    if (!username) {
        setError(
            usernameInput,
            usernameError,
            "Username is required."
        );
        isValid = false;
    }

    if (!password) {
        setError(
            passwordInput,
            passwordError,
            "Password is required."
        );
        isValid = false;
    }

    return isValid;
}

// Show / Hide Password
togglePassword.addEventListener("click", () => {
    const isHidden = passwordInput.type === "password";

    passwordInput.type = isHidden ? "text" : "password";

    togglePassword.setAttribute(
        "aria-label",
        isHidden ? "Hide password" : "Show password"
    );

    togglePassword.setAttribute(
        "aria-pressed",
        String(isHidden)
    );

    if (isHidden) {
        // Eye-off icon
        togglePasswordIconPath.setAttribute(
            "d",
            "M17.94 17.94A10.94 10.94 0 0 1 12 19c-6.5 0-10-7-10-7a21.77 21.77 0 0 1 5.06-5.94M9.9 4.24A10.93 10.93 0 0 1 12 5c6.5 0 10 7 10 7a21.8 21.8 0 0 1-3.38 4.62M1 1l22 22"
        );

        togglePasswordIconCircle.style.display = "none";
    } else {
        // Normal eye icon
        togglePasswordIconPath.setAttribute(
            "d",
            "M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7z"
        );

        togglePasswordIconCircle.style.display = "block";
    }
});

// Clear Errors When Typing
usernameInput.addEventListener("input", () => {
    setError(usernameInput, usernameError, "");
    formMessage.textContent = "";
});

passwordInput.addEventListener("input", () => {
    setError(passwordInput, passwordError, "");
    formMessage.textContent = "";
});

// Set Login Loading State
function setLoading(isLoading) {
    loginButton.disabled = isLoading;
    usernameInput.disabled = isLoading;
    passwordInput.disabled = isLoading;

    loginButton.textContent = isLoading
        ? "Signing in..."
        : "Sign In";
}

// Real Backend Login Request
async function login(username, password) {
    const response = await fetch(
        `${API_BASE_URL}/api/auth/login`,
        {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify({
                username,
                password
            })
        }
    );

    const data = await response.json().catch(() => ({}));

    if (!response.ok) {
        if (response.status === 401) {
            throw new Error("Invalid username or password.");
        }

        if (response.status === 400) {
            throw new Error(
                data.error || "Please check your login information."
            );
        }

        throw new Error(
            data.error || `Login failed (HTTP ${response.status}).`
        );
    }

    // Validate Backend Response
    if (
        typeof data.token !== "string" ||
        !data.token ||
        !data.user ||
        typeof data.user.id !== "string" ||
        typeof data.user.username !== "string" ||
        !["admin", "reader"].includes(data.user.role)
    ) {
        throw new Error("Invalid login response from Backend.");
    }

    return data;
}

// Submit Login Form
form.addEventListener("submit", async (event) => {
    event.preventDefault();

    if (loginButton.disabled) return;

    formMessage.textContent = "";

    if (!validateForm()) {
        const firstInvalid = form.querySelector(
            '[aria-invalid="true"]'
        );

        firstInvalid?.focus();
        return;
    }

    const username = usernameInput.value.trim();
    const password = passwordInput.value;

    setLoading(true);

    try {
        // Call Real Login API
        const data = await login(username, password);

        // Save Token and User for navigation between pages
        window.RARAuth.saveSession(data);

    // Clear password
        passwordInput.value = "";

        // Handle redirect after successful login
        const requestedNext = new URLSearchParams(window.location.search).get("next");
        const next = data.user.role === "admin" && requestedNext === "articleEditor.html"? "./articleEditor.html": "./index.html";
        window.location.assign(next);

    } catch (error) {
        const message = error instanceof TypeError
            ? "Cannot connect to Backend. Check Spring Boot."
            : error.message || "Login failed. Please try again.";

        formMessage.textContent = message;

    } finally {
        setLoading(false);
    }
});
    // Message when Guest tries to access Admin page
if ( new URLSearchParams(window.location.search).get("reason") === "admin-required") {
    formMessage.textContent ="Sign in with an administrator account to manage content.";
}
