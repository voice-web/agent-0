# globe-landing static site image.
# Runtime: small stdlib static server (no Python version in Server header).
FROM python:3.12-slim-bookworm

WORKDIR /srv/www

COPY serve.py /srv/serve.py

# Baked site content.
COPY site/ /srv/www/

ENV PORT=8080
ENV GLOBE_LANDING_ROOT=/srv/www

EXPOSE 8080

CMD ["sh", "-c", "exec python3 /srv/serve.py"]

