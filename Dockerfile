# Create the Cf-Connecting-Ip plugin directory to be able to get the real ip
FROM alpine:3

ARG PLUGIN_MODULE=github.com/kubitodev/traefik-cloudflared-source-ip
ARG PLUGIN_GIT_REPO=https://github.com/kubitodev/traefik-cloudflared-source-ip.git
ARG PLUGIN_GIT_BRANCH=main

RUN apk add --update git && \
    git clone ${PLUGIN_GIT_REPO} /plugins-local/src/${PLUGIN_MODULE} \
    --depth 1 --single-branch --branch ${PLUGIN_GIT_BRANCH}

# Copy the plugin into the traefik image
FROM traefik:2.10

COPY --from=0 /plugins-local /plugins-local
