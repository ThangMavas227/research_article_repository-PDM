/* Only used to simulate backend search while in mock demo mode.
 * In API mode, the server performs the search using the `keyword` parameter.
 */
function normalizeText(text) {
    return String(text ?? '')
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .replace(/đ/g, 'd')
        .replace(/Đ/g, 'D')
        .toLowerCase()
        .trim();
}

function searchArticles(articles, keyword) {
    const query = normalizeText(keyword);
    if (!query) return articles;

    return articles.filter(article => {
        const title = normalizeText(article.title);
        const authors = (article.authors || [])
            .map(author => normalizeText(author.name))
            .join(' ');
        return title.includes(query) || authors.includes(query);
    });
}
