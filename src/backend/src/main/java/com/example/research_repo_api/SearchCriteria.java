package com.example.research_repo_api;

import java.util.Locale;

/** Shared search-filter semantics for GET /api/articles and saved-search JSON. */
public record SearchCriteria(String keyword, Integer yearFrom, Integer yearTo, String venueType) {

    /** Normalizes optional strings, checks year bounds, and validates Journal/Conference values. */
    public static SearchCriteria normalized(String keyword, Integer yearFrom, Integer yearTo, String venueType) {
        validateYear("yearFrom", yearFrom);
        validateYear("yearTo", yearTo);
        if (yearFrom != null && yearTo != null && yearFrom > yearTo) {
            throw new BadRequestException("yearFrom must be <= yearTo");
        }

        String normalizedKeyword = keyword == null ? null : keyword.trim();
        if (normalizedKeyword != null && normalizedKeyword.isEmpty()) normalizedKeyword = null;
        if (normalizedKeyword != null && normalizedKeyword.length() > 255) {
            throw new BadRequestException("keyword must be at most 255 characters");
        }

        String normalizedVenue = venueType == null ? null : venueType.trim().toUpperCase(Locale.ROOT);
        if (normalizedVenue != null && normalizedVenue.isEmpty()) normalizedVenue = null;
        if (normalizedVenue != null && !normalizedVenue.equals("J") && !normalizedVenue.equals("C")) {
            throw new BadRequestException("venueType must be J or C");
        }
        return new SearchCriteria(normalizedKeyword, yearFrom, yearTo, normalizedVenue);
    }

    public SearchCriteria normalized() {
        return normalized(keyword, yearFrom, yearTo, venueType);
    }

    public static void validateYear(String label, Integer year) {
        if (year != null && (year < 1 || year > 9999)) {
            throw new BadRequestException(label + " must be between 1 and 9999");
        }
    }
}
