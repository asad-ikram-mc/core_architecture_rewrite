# Amazon CORE docs (sign-in shell)

This repo only publishes the sign-in page for the Amazon CORE architecture docs on GitHub Pages.
The content is not stored here: after sign-in (CORE dashboard accounts) each page is fetched
from the `core-docs-data` API, which checks the token on every request.

The source lives in a private repo, which also holds the backend and the publish scripts.
