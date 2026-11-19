
"use strict";

// DOM Elements
const form = document.getElementById("login-form");
const usernameInput = document.getElementById("username");
const passwordInput = document.getElementById("password");

const usernameError = document.getElementById("username-error");
const passwordError = document.getElementById("password-error");
const formMessage = document.getElementById("form-message");

const togglePassword = document.getElementById("toggle-password");
const togglePasswordIconPath = document.getElementById(
    "toggle-password-icon-path"
);
const togglePasswordIconCircle = document.getElementById(
    "toggle-password-icon-circle"
);

// Display validation error
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

    if (!password.trim()) {
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

    // Toggle input visibility
    passwordInput.type = isHidden ? "text" : "password";

    // Update accessibility attributes
    togglePassword.setAttribute(
        "aria-label",
        isHidden ? "Hide password" : "Show password"
    );

    togglePassword.setAttribute(
        "aria-pressed",
        String(isHidden)
    );

    // Toggle eye / eye-off icon
    if (isHidden) {
        // Password is now visible: eye-off
        togglePasswordIconPath.setAttribute(
            "d",
            "M17.94 17.94A10.94 10.94 0 0 1 12 19c-6.5 0-10-7-10-7a21.77 21.77 0 0 1 5.06-5.94M9.9 4.24A10.93 10.93 0 0 1 12 5c6.5 0 10 7 10 7a21.8 21.8 0 0 1-3.38 4.62M1 1l22 22"
        );

        togglePasswordIconCircle.style.display = "none";
    } else {
        // Password is now hidden: normal eye
        togglePasswordIconPath.setAttribute(
            "d",
            "M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7z"
        );

        togglePasswordIconCircle.style.display = "block";
    }
});

// Clear errors when typing
usernameInput.addEventListener("input", () => {
    setError(usernameInput, usernameError, "");
    formMessage.textContent = "";
});

passwordInput.addEventListener("input", () => {
    setError(passwordInput, passwordError, "");
    formMessage.textContent = "";
});

// Handle Login Form Submission
form.addEventListener("submit", (event) => {
    event.preventDefault();

    formMessage.textContent = "";

    if (!validateForm()) {
        const firstInvalid = form.querySelector(
            '[aria-invalid="true"]'
        );

        firstInvalid?.focus();
        return;
    }

    // Backend Authentication API is not integrated yet.
    // No fake token or fake login session is created.
    formMessage.textContent =
        "Login is not available until backend integration is complete.";
});
