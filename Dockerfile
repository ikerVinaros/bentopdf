# Declaración de variable global:
# Construir para servir bajo subdirectorio BASE_URL si se proporciona, ej: "ARG BASE_URL=/pdf/", de lo contrario dejar en blanco: "ARG BASE_URL="
ARG BASE_URL=

# Etapa de construcción
FROM public.ecr.aws/docker/library/node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
COPY vendor ./vendor
ENV HUSKY=0
RUN npm config set fetch-retries 5 && \
    npm config set fetch-retry-mintimeout 60000 && \
    npm config set fetch-retry-maxtimeout 300000 && \
    npm config set fetch-timeout 600000 && \
    npm ci
COPY . .

# Construir sin verificación de tipos (solo vite build)
# Pasa la variable de entorno SIMPLE_MODE si se proporciona
ARG SIMPLE_MODE=false
ENV SIMPLE_MODE=$SIMPLE_MODE
ARG COMPRESSION_MODE=all
ENV COMPRESSION_MODE=$COMPRESSION_MODE

# argumento global a argumento local - BASE_URL se lee del entorno por vite.config.ts
ARG BASE_URL
ENV BASE_URL=$BASE_URL

# URLs de módulos WASM (valores predeterminados preconfigurados)
# Anula estos para implementaciones sin conexión o autohospedadas de WASM
ARG VITE_WASM_PYMUPDF_URL
ARG VITE_WASM_GS_URL
ARG VITE_WASM_CPDF_URL
ENV VITE_WASM_PYMUPDF_URL=$VITE_WASM_PYMUPDF_URL
ENV VITE_WASM_GS_URL=$VITE_WASM_GS_URL
ENV VITE_WASM_CPDF_URL=$VITE_WASM_CPDF_URL

# URLs de recursos OCR (opcional, usado para OCR autohospedado o sin conexión)
ARG VITE_TESSERACT_WORKER_URL
ARG VITE_TESSERACT_CORE_URL
ARG VITE_TESSERACT_LANG_URL
ARG VITE_TESSERACT_AVAILABLE_LANGUAGES
ARG VITE_OCR_FONT_BASE_URL
ENV VITE_TESSERACT_WORKER_URL=$VITE_TESSERACT_WORKER_URL
ENV VITE_TESSERACT_CORE_URL=$VITE_TESSERACT_CORE_URL
ENV VITE_TESSERACT_LANG_URL=$VITE_TESSERACT_LANG_URL
ENV VITE_TESSERACT_AVAILABLE_LANGUAGES=$VITE_TESSERACT_AVAILABLE_LANGUAGES
ENV VITE_OCR_FONT_BASE_URL=$VITE_OCR_FONT_BASE_URL

# Idioma predeterminado de la interfaz (ej. en, fr, de, es, zh, ar)
ARG VITE_DEFAULT_LANGUAGE
ENV VITE_DEFAULT_LANGUAGE=$VITE_DEFAULT_LANGUAGE

# Marca personalizada (ej. VITE_BRAND_NAME=MiEmpresa VITE_BRAND_LOGO=mi-logo.svg)
ARG VITE_BRAND_NAME
ARG VITE_BRAND_LOGO
ARG VITE_FOOTER_TEXT
ENV VITE_BRAND_NAME=$VITE_BRAND_NAME
ENV VITE_BRAND_LOGO=$VITE_BRAND_LOGO
ENV VITE_FOOTER_TEXT=$VITE_FOOTER_TEXT

ENV NODE_OPTIONS="--max-old-space-size=3072"

RUN --mount=type=secret,id=VITE_CORS_PROXY_URL \
    --mount=type=secret,id=VITE_CORS_PROXY_SECRET \
    VITE_CORS_PROXY_URL=$(cat /run/secrets/VITE_CORS_PROXY_URL 2>/dev/null || echo "") \
    VITE_CORS_PROXY_SECRET=$(cat /run/secrets/VITE_CORS_PROXY_SECRET 2>/dev/null || echo "") \
    npm run build:with-docs

# Etapa de producción
FROM quay.io/nginx/nginx-unprivileged:stable-alpine-slim

LABEL org.opencontainers.image.source="https://github.com/alam00000/vinaros"
LABEL org.opencontainers.image.url="https://github.com/alam00000/vinaros"

# argumento global a argumento local
ARG BASE_URL

# Establece esto en "true" para deshabilitar la escucha de Nginx en IPv6
ENV DISABLE_IPV6=false

USER root
RUN apk upgrade --no-cache
USER nginx

COPY --chown=nginx:nginx --from=builder /app/dist /usr/share/nginx/html${BASE_URL%/}
COPY --chown=nginx:nginx nginx.conf /etc/nginx/nginx.conf
COPY --chown=nginx:nginx --chmod=755 nginx-ipv6.sh /docker-entrypoint.d/99-disable-ipv6.sh
RUN mkdir -p /etc/nginx/tmp && chown -R nginx:nginx /etc/nginx/tmp

EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
