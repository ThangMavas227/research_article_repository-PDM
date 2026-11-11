
/**
 * Filter articles by title or author name.
 *
 * @param {Array} articles - List of articles.
 * @param {string} keyword - Search keyword.
 * @returns {Array} Matching articles.
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

    if (query === '') {
        return articles;
    }

    return articles.filter(article => {
        const title = normalizeText(article.title);
        return title.includes(query);
    });
}



const testArticles = [
    {
        title: "Machine Learning in Healthcare",
        authors: ["Nguyen Van A", "Tran Thi B"],
        pubYear: 2024
    },
    {
        title: "Database Management Systems",
        authors: ["Le Van C"],
        pubYear: 2023
    }
];

console.log(
    "Test 1:",
    searchArticles(testArticles, "Machine")
);

console.log(
    "Test 2:",
    searchArticles(testArticles, "Le Van C")
);

console.log(
    "Test 3:",
    searchArticles(testArticles, "xyz123")
);

console.log(
    "Test 4:",
    searchArticles(testArticles, "")
);

