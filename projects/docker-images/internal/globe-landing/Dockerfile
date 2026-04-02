# globe-landing static site image.
# Runtime: python3 -m http.server <PORT>
FROM python:3.12-slim-bookworm

WORKDIR /srv/www

# Baked site content.
COPY site/ /srv/www/

ENV PORT=8080

EXPOSE 8080

CMD ["sh", "-c", "exec python3 -m http.server ${PORT} --bind 0.0.0.0 --directory /srv/www"]

