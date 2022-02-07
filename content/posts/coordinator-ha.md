---
title: "Coordinator HA in Trino with reverse nginx proxy"
date: 2022-01-10T11:18:51-05:00
draft: true
---

Demonstrate coordinator HA

```
upstream trino {
   server trino_a:8080 fail_timeout=3s max_fails=1;
   server trino_b:8081 backup;
}

server {
    listen       80;
    server_name  localhost;
    location / {
        proxy_pass   http://trino;
        proxy_redirect  http://trino/ /;
        proxy_connect_timeout 3;

        proxy_set_header          Host            $host;
        proxy_set_header          X-Real-IP       $remote_addr;
        proxy_set_header          X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

The `upstream` section of the Nginx config is what configures the servers behind
the reverse proxy. The backup directive indicates no traffic will go to `trino_b`
until `trino_a` has a timeout failure of 3 seconds.

In the `server` section, the proxy is configured to listen on port 80. This is
the port our end users will be connecting to Trino with. The `location` section
then configures the proxy to pass all traffic to http://trino

The `proxy_set_header` options are required in order to ensure that POST requests
are forwarded correctly by the proxy to Trino.
