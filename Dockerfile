# syntax=docker/dockerfile:1.4

FROM alpine as build-environment
ARG TARGETARCH
WORKDIR /opt
RUN apk add clang lld curl build-base linux-headers git \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs > rustup.sh \
    && chmod +x ./rustup.sh \
    && ./rustup.sh -y

RUN [[ "$TARGETARCH" = "arm64" ]] && echo "export CFLAGS=-mno-outline-atomics" >> $HOME/.profile || true

WORKDIR /opt/foundry
COPY . .

RUN --mount=type=cache,target=/root/.cargo/registry --mount=type=cache,target=/root/.cargo/git --mount=type=cache,target=/opt/foundry/target \
    source $HOME/.profile && cargo build --release \
    && mkdir out \
    && cp target/release/forge out/forge \
    && cp target/release/cast out/cast \
    && cp target/release/anvil out/anvil \
    && strip out/forge \
    && strip out/cast \
    && strip out/anvil

FROM alpine as foundry-client
ENV GLIBC_KEY=https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub
ENV GLIBC_KEY_FILE=/etc/apk/keys/sgerrand.rsa.pub
ENV GLIBC_RELEASE=https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r0/glibc-2.35-r0.apk

RUN apk add linux-headers gcompat git
RUN wget -q -O ${GLIBC_KEY_FILE} ${GLIBC_KEY} \
    && wget -O glibc.apk ${GLIBC_RELEASE} \
    && apk add glibc.apk --force
COPY --from=build-environment /opt/foundry/out/forge /usr/local/bin/forge
COPY --from=build-environment /opt/foundry/out/cast /usr/local/bin/cast
COPY --from=build-environment /opt/foundry/out/anvil /usr/local/bin/anvil
RUN adduser -Du 1000 foundry
ENTRYPOINT ["/bin/sh", "-c"]
