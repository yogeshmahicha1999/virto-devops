FROM node:22-slim AS build
ARG VC_FRONTEND_REF
ENV HUSKY=0 CI=true NODE_OPTIONS=--max-old-space-size=4096
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git init -q . \
 && git remote add origin https://github.com/VirtoCommerce/vc-frontend.git \
 && git fetch -q --depth 1 origin "$VC_FRONTEND_REF" \
 && git checkout -q FETCH_HEAD
RUN corepack enable && yarn install --immutable
RUN yarn build-only

FROM nginx:1.28-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/dist /usr/share/nginx/html
