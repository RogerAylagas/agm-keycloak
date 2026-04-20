ARG KC_VERSION=26.1.4
FROM quay.io/keycloak/keycloak:${KC_VERSION} AS builder

ENV KC_DB=postgres
ENV KC_FEATURES=token-exchange,admin-fine-grained-authz
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true
ENV KC_HTTP_RELATIVE_PATH=/

RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:${KC_VERSION}

COPY --from=builder /opt/keycloak/lib /opt/keycloak/lib
COPY --from=builder /opt/keycloak/providers /opt/keycloak/providers

RUN mkdir -p /opt/keycloak/data/import

USER 1000

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
