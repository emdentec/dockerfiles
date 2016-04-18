# Lets Encrypt Docker Image

The purpose of this image is to allow letsencrypt to be used alongside `nginx` by using volumes. To use it you will need a [data container](http://container42.com/2014/11/18/data-only-container-madness/) for letsencrypt and an nginx image that forwards to other containers. The example below shows how to secure a jenkins image using this method.

```bash
# Create a jenkins container
docker run --name jenkins emdentec/jenkins

# Create a data container for letsencrypt
docker run \
    --name letsencrypt-data \
    --net none \
    --entrypoint /bin/echo \
    emdentec/letsencrypt \
    Data container for letsencrypt

# Create an nginx container
docker run \
    --name nginx \
    -d -p 80:80 -p 443:443 \
    --volumes-from letsencrypt-data \
    -v host/path/to/nginx.conf:/etc/nginx/conf.d/default.conf:ro \
    --link jenkins:jenkins \
    nginx
```

Where `nginx.conf` is similar to:

```
map $http_x_forwarded_proto $proxy_x_forwarded_proto {
  default $http_x_forwarded_proto;
  ''      $scheme;
}
# If we receive Upgrade, set Connection to "upgrade"; otherwise, delete any
# Connection header that may have been passed to this server
map $http_upgrade $proxy_connection {
  default upgrade;
  '' close;
}
gzip_types text/plain text/css application/javascript application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;
log_format vhost '$host $remote_addr - $remote_user [$time_local] '
                 '"$request" $status $body_bytes_sent '
                 '"$http_referer" "$http_user_agent"';
access_log off;
# HTTP 1.1 support
proxy_http_version 1.1;
proxy_buffering off;
proxy_set_header Host $http_host;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection $proxy_connection;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $proxy_x_forwarded_proto;

ssl_certificate /etc/letsencrypt/live/jenkins.example.com/cert.pem;
ssl_certificate_key /etc/letsencrypt/live/jenkins.example.com/privkey.pem;

server {
    server_name _; # This is just an invalid value which will never trigger on a real hostname.
    listen 80;
    access_log /var/log/nginx/access.log vhost;
    return 503;
}

upstream jenkins.example.com {
    # jenkins
    server jenkins:8080;
}
server {
    server_name jenkins.example.com;
    listen 80 default_server;
    access_log /var/log/nginx/access.log vhost;
    location / {
        return 301 https://$host$request_uri;
    }
    location /.well-known {
        root /var/www/letsencrypt;
    }
}
server {
    server_name jenkins.example.com;
    listen 443 ssl;

    location / {
        proxy_pass http://jenkins.example.com;
        allow 86.0.93.185;
        deny all;
    }
}
```

You can then use letsencrypt to generate or renew certificates.

```bash
# Generate certificate
docker run \
    --rm -ti \
    --volumes-from letsencrypt-data \
    emdentec/letsencrypt \
        certonly --webroot \
        -w /var/www/letsencrypt \
        -d jenkins.example.com \
        --agree-tos -t \
        --email jenkins@example.com

# Renew certificate
docker run \
    --rm -ti \
    --volumes-from letsencrypt-data \
    emdentec/letsencrypt \
        renew
```