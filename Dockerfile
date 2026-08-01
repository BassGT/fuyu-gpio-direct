# Usamos la imagen oficial de Haskell para extraer los binarios precompilados
FROM --platform=linux/arm64 haskell:9.10.3-slim-bookworm AS haskell-source

# Nuestra imagen base moderna con libgpiod v2
FROM --platform=linux/arm64 debian:trixie-slim

# Directorio de trabajo
WORKDIR /app

# Instalamos las dependencias esenciales de Haskell y libgpiod v2
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dpkg-dev \
        git \
        gcc \
        gnupg \
        g++ \
        libc6-dev \
        libffi-dev \
        libgmp-dev \
        libnuma-dev \
        libtinfo-dev \
        make \
        netbase \
        xz-utils \
        zlib1g-dev \
        pkg-config \
        binutils \
        binutils-gold \
        gpiod \
        libgpiod-dev && \
    rm -rf /var/lib/apt/lists/*

# Copiamos GHC, Cabal y Stack directamente desde la imagen oficial
COPY --from=haskell-source /opt/ghc /opt/ghc
COPY --from=haskell-source /usr/local/bin/cabal /usr/local/bin/cabal
COPY --from=haskell-source /usr/local/bin/stack /usr/local/bin/stack

# Configuramos el entorno exactamente como en la imagen oficial
ENV LANG=C.UTF-8
ENV PATH=/root/.cabal/bin:/root/.local/bin:/opt/ghc/9.10.3/bin:$PATH

CMD ["ghci"]
