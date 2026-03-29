Copied to /srv/www in the image (with this file present).

- Add index.html (here or via volume mount) → GET / and HEAD / serve that file.
- No index.html → GET / and other methods on / return JSON echo of the request (headers, query, body, etc.).
