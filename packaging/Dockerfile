FROM python:3.12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends rpm zip \
    && pip install --no-cache-dir "https://github.com/aristanetworks/swi-tools/archive/11fb38f17333a190ed7421dc47448d765988a5d6.tar.gz" \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
CMD ["packaging/build.sh"]
