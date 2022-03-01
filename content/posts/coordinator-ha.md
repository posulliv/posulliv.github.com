---
title: "Coordinator HA in Trino with reverse nginx proxy"
date: 2022-01-10T11:18:51-05:00
draft: false
---

> All config files and a full `docker-compose.yaml` file for recreating
> what is covered in this article can be found in
> [this github repository](https://github.com/posulliv/trino-coordinator-ha-demo).

This article demonstrates how coordinator HA can be achieved with an nginx
reverse proxy using docker. Note that this is not a production setup. The
intent of this article is to show how coordinator HA can be achieved. I've
used similar concepts with real-world deployments but I've used a hardware
load balancer instead of nginx for this in production.

With that said, lets continue! We will set up 3 Trino containers:

* coordinator A listening on port 8080- named `trino_a`
* coordinator B listening on port 8081 - named `trino_b`
* worker - named `trino_worker`

We will also start an Nginx container named Nginx. The nginx configuration for
setting up the reverse proxy will look like:

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

The discovery URI for the coordinators needs to point at localhost to ensure they
never communicate with a different coordinator. 

Coordinator A `config.properties` looks like:

```
coordinator=true
node-scheduler.include-coordinator=true
http-server.http.port=8080
query.max-memory=1.4GB
query.max-memory-per-node=1.4GB
query.max-total-memory-per-node=1.4GB
discovery.uri=http://localhost:8080
```

Coordinator B `config.properties` looks like:

```
coordinator=true
node-scheduler.include-coordinator=true
http-server.http.port=8081
query.max-memory=1.4GB
query.max-memory-per-node=1.4GB
query.max-total-memory-per-node=1.4GB
discovery.uri=http://localhost:8081
```

Now any worker must be configured to use the URL of the reverse proxy for
`discovery.uri`. This means that if one of the coordinator’s go down, the
worker will start making announcements to the backup coordinator since all
its requests go through the reverse proxy. The worker’s `config.properties`
looks like:

```
coordinator=false
query.max-memory=1.4GB
query.max-memory-per-node=1.4GB
query.max-total-memory-per-node=1.4GB
discovery.uri=http://nginx:80
```

Assuming we have started up all our containers, an end user would connect
using the CLI like so:

```
trino --server http://localhost/ --user padraig --debug
```

Verify we have a coordinator and 1 worker in this cluster:

```
trino> select * from system.runtime.nodes;
   node_id    |        http_uri        | node_version | coordinator | state
--------------+------------------------+--------------+-------------+--------
 f8150fcfb049 | http://172.30.0.2:8080 | 364          | true        | active
 4c10ceb56ca3 | http://172.30.0.3:8080 | 364          | false       | active
(2 rows)

Query 20211202_151305_00000_3cki7, FINISHED, 2 nodes
http://localhost/ui/query.html?20211202_151305_00000_3cki7

trino>
```

Now, kill the active coordinator container trino_a and verify we can still
connect and still have 1 worker in the cluster:

```
trino> select * from system.runtime.nodes;
   node_id    |        http_uri        | node_version | coordinator | state
--------------+------------------------+--------------+-------------+--------
 4c10ceb56ca3 | http://172.30.0.3:8080 | 364          | false       | active
 8a42a7e8d105 | http://172.30.0.4:8081 | 364          | true        | active
(2 rows)

Query 20211202_151406_00001_ewe87, FINISHED, 2 nodes
http://localhost/ui/query.html?20211202_151406_00001_ewe87

trino>
```

Notice the `http_uri` of the coordinator is different (now port 8081) which
indicates we are using the `trino_b` coordinator.

Again, this is not a production setup but demonstrates how coordinator HA can
be achieved in a Trino cluster.