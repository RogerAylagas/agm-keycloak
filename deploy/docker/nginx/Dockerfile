FROM nginx:1.27-alpine

RUN apk add --no-cache openssl

COPY deploy/docker/nginx/nginx.conf /etc/nginx/nginx.conf

RUN mkdir -p /etc/nginx/certs && \
    openssl req -x509 -newkey rsa:2048 -keyout /etc/nginx/certs/key.pem \
    -out /etc/nginx/certs/cert.pem -days 365 -nodes -subj "/CN=localhost"

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
