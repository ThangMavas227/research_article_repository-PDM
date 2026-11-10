
const params = new URLSearchParams(window.location.search);
const articleId = params.get('id');

const articles = window.MOCK_ARTICLES;
const details = window.MOCK_DETAILS;

const article = articles.find(a => a.id === articleId);
const detailEl = document.getElementById('articleDetail');

// Display the list of citations
function renderCitations(ids, containerId) {
    const container = document.getElementById(containerId);
    container.replaceChildren();

    const relatedArticles = ids
        .map(id => articles.find(a => a.id === id))
        .filter(Boolean);

    // Empty State
    if (relatedArticles.length === 0) {
        const empty = document.createElement('div');
        empty.className = 'state-box';

        const title = document.createElement('div');
        title.className = 'state-title';
        title.textContent = 'No citations found';

        const message = document.createElement('p');
        message.textContent = 'No citations available in mock data.';

        empty.append(title, message);
        container.appendChild(empty);
        return;
    }

    // Display each related article
    relatedArticles.forEach(item => {
        const row = document.createElement('article');
        row.className = 'article-row';

        const title = document.createElement('h3');
        title.className = 'article-title';

        const link = document.createElement('a');
        link.href = `articleDetail.html?id=${item.id}`;
        link.textContent = item.title;

        title.appendChild(link);

        const meta = document.createElement('div');
        meta.className = 'article-meta';
        meta.textContent =
            `${item.authors.map(a => a.name).join(', ')} (${item.year})`;

        row.append(title, meta);
        container.appendChild(row);
    });
}

// Display article
if (!article) {
    detailEl.innerHTML = `
        <div class="state-box">
            <h2 class="state-title">Article not found</h2>
            <p>The requested article does not exist.</p>
        </div>
    `;
} else {
    const detail = details[article.id];

    document.getElementById('detail-title').textContent =
        article.title;

    document.getElementById('detail-authors').textContent =
        article.authors.map(a => a.name).join(', ');

    document.getElementById('detail-year').textContent =
        article.year;

    document.getElementById('detail-doi').textContent =
        detail?.doi || 'Not available';

    document.getElementById('detail-abstract').textContent =
        detail?.abstract || 'Abstract not available.';

    // Bài này trích dẫn các bài nào?
    const references = detail?.references || [];

    // Những bài nào trích dẫn bài này?
    const citedBy = Object.keys(details).filter(id =>
        details[id].references.includes(article.id)
    );

    renderCitations(references, 'references-list');
    renderCitations(citedBy, 'cited-by-list');
}
