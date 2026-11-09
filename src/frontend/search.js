
/**
 * Filter articles by title or author name.
 *
 * @param {Array} articles - List of articles.
 * @param {string} keyword - Search keyword.
 * @returns {Array} Matching articles.
 */
function searchArticles(articles, keyword) {
    const query = keyword.trim().toLowerCase();

    if (query === "") {
        return articles;
    }

    return articles.filter(article => {
        const title = article.title.toLowerCase();
        const authors = article.authors
            .join(" ")
            .toLowerCase();

        return title.includes(query)
            || authors.includes(query);
    });
}
