---
title: "Deploying Lyft's Presto Gateway on Google Cloud with helm"
date: 2022-04-12T08:53:46-04:00
draft: false
---

Lyft's [gateway project](https://github.com/lyft/presto-gateway) is a popular
open source solution for a gateway that can be deployed in front of multiple
Trino clusters. Lyft has more information on how it works in a [blog post](https://eng.lyft.com/presto-infrastructure-at-lyft-b10adb9db01)
on their engineering blog.

I wanted to deploy this solution on Google Kubernetes Engine but I could not
find any docker image or helm charts available. The instructions for deployment
did not cover this deployment method either.

Thus, I created a docker image and a helm chart for the project. You can see the source for
the helm chart and scripts I used to create the docker image in [my github repository](https://github.com/posulliv/lyft-gateway-charts).

In this post, I'm going to cover how to use the helm chart to deploy a Trino
gateway on Google Kubernetes Engine.

# Configure chart repository

The first thing we need to do is add the chart repository that contains my
helm chart for Lyft's gatway:

```
helm repo add gateway https://posulliv.github.io/lyft-gateway-charts
helm repo update
```

# Deploy MySQL

The only prerequisite to using Lyft's gateway is a MySQL database. For this
article, I am going to deploy a temporary MySQL database in my kubernetes
cluster. This is not a recommended approach for a production deployment
as the MySQL database is a single point of failure for the gateway. If the
gateway cannot connect to a MySQL database, it will cease to function correctly.

With that said, here is the values I will use for deploying MySQL in my
kubernetes cluster:

```
auth:
  database: gateway
  rootPassword: root

primary:
  service:
    type: LoadBalancer
    port: 3306
```

Now I am going to deploy MySQL via `helm`:

```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install mysql bitnami/mysql --values mysql.yaml
curl -LJO https://raw.githubusercontent.com/lyft/presto-gateway/master/gateway-ha/src/main/resources/gateway-ha-persistence.sql
mysql -h $mysql_ip -u root -proot gateway < gateway-ha-persistence.sql
```

Notice that I retrieved a SQL file with the schema needed by Lyft's gateway
from the github repository for the project. I also referenced `$mysql_ip` in
the above command. This will be the external IP of the MySQL database since I 
deployed with a `LoadBalancer`. It may take some time for an external IP to be
assigned.

# Deploy multiple gateway pods

Now we are ready to deploy Lyft's gateway. The nice thing about deploying on
a kubernetes platform is I can easily deploy multiple gateway pods. The helm
chart has support for this by simply specifying how many pods are needed in
the `replicaCount` parameter.

Below is the YAML I am going to use for deploying the gateway.

```
image:
  repository: posulliv/gateway
  pullPolicy: IfNotPresent
  # Overrides the image tag whose default is the chart appVersion.
  tag: latest

replicaCount: 4

backendDatabase:
  host: mysql
  port: 3306
  schema: gateway
  user: root
  password: root

service:
  type: NodePort
  requestPort: 8080
  appPort: 8090
  adminPort: 8091
```

Now, we can deploy this via `helm`:

```
helm install trino-gateway gateway/gateway --version 0.2.6 --values gateway.yaml
```

Once this completes, we should have 4 gateway pods running:

```
NAME                            READY   STATUS    RESTARTS   AGE
mysql-0                         1/1     Running   0          15h
trino-gateway-65bd4689f-69zfg   1/1     Running   0          72s
trino-gateway-65bd4689f-bqt4h   1/1     Running   0          72s
trino-gateway-65bd4689f-gcv6b   1/1     Running   0          72s
trino-gateway-65bd4689f-jsszh   1/1     Running   0          72s
```

# Expose gateway via an ingress

The gateway service was exposed via `NodePort` and we are now going to create
an ingress for it.

First we need to create a static IP address:

```
gcloud compute addresses create gateway-static-ip --global
```

Now, we can create an ingress and associate the static IP address we created
with it:

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: gateway-ingress
  annotations:
    kubernetes.io/ingress.global-static-ip-name: "gateway-static-ip"
spec:
  defaultBackend:
    service:
      name: trino-gateway
      port:
        number: 8080
```

We will deploy this with `kubectl`:

```
kubectl apply -f ingress.yaml
```

Finally, we need to configure a DNS A record for the static IP we created.

Once the DNS record is created, we can access the gateway via the DNS record
we created. 

If we open the gateway URL in a web browser, we should now see the gateway UI.

![Gateway web UI](/img/gateway_notls_ui.png)

# Add some trino clusters

Let's now deploy 2 single node Trino clusters with `helm`. For a more in-depth
guide to deploy Trino on helm, please see [my earlier post](https://posulliv.github.io/posts/trino-helm/)
on the topic.

For this post, we are going to use the same YAML for both Trino clusters:

```
server:
  node:
    environment: gateway
  workers: 0

service:
  type: LoadBalancer
```

We will deploy 2 Trino clusters:

```
helm install trino-a trino/trino --version 0.8.0 --values trino.yaml
helm install trino-b trino/trino --version 0.8.0 --values trino.yaml
```

We should now have 2 Trino single node deployments:

```
trino-a-coordinator-745c8875dc-vf6cp   1/1     Running   0          41s
trino-b-coordinator-77976bdbdd-d7zzv   1/1     Running   0          33s
```

Now, we can add these clusters as backends using the gateway's REST API:

```
curl -X POST http://trino-gateway.starburst-customer-success.com/entity\?entityType=GATEWAY_BACKEND \
-d '{  "name": "trino-a",
        "proxyTo": "http://trino_a_ip:8080",
        "active": true,
        "routingGroup": "adhoc"
    }'
curl -X POST http://trino-gateway.starburst-customer-success.com/entity\?entityType=GATEWAY_BACKEND \
-d '{  "name": "trino-b",
        "proxyTo": "http://trino_b_ip:8080",
        "active": true,
        "routingGroup": "adhoc"
    }'
```

Once the above `curl` commands complete, we should see 2 backends in the
gateway web UI.

![Gateway backends](/img/gateway_backends.png)

We should also be able to connect via the Trino CLI and execute queries.

```
$ trino --server http://trino-gateway.starburst-customer-success.com --user padraig
trino> show catalogs;
 Catalog
---------
 system
 tpcds
 tpch
(3 rows)

Query 20220412_013906_00000_5q4vw, FINISHED, 1 node
Splits: 4 total, 4 done (100.00%)
2.87 [0 rows, 0B] [0 rows/s, 0B/s]

trino>
```

# TLS termination at gateway

Now we want to enable TLS and terminate it at the ingress that is in front of
our gateway.

Since we are deploying on Google Cloud, we will use [Google Managed Certificates](https://cloud.google.com/load-balancing/docs/ssl-certificates/google-managed-certs)
for enabling TLS to the gateway.

The first thing we need to do is create a managed certificate with the DNS
record we configured for the static IP we created. We will place the following
in a `managed-cert.yaml` file:

```
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: managed-cert
spec:
  domains:
    - trino-gateway.starburst-customer-success.com
```

And we will deploy it with `kubectl`:

```
kubectl apply -f managed-cert.yaml
```

It can take up to 60 minutes to provision a managed certificate on the
Google Cloud Platform. Once it is provisioned, it should show a status of
`Active`:

```
$ kubectl get managedcertificate
NAME           AGE   STATUS
managed-cert   47h   Active
$
```

Now we are ready to modify our ingress. We will put the following in an
`ingress.yaml` file:

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: gateway-ingress
  annotations:
    kubernetes.io/ingress.global-static-ip-name: "gateway-static-ip"
    networking.gke.io/managed-certificates: managed-cert
    kubernetes.io/ingress.class: "gce"
spec:
  defaultBackend:
    service:
      name: trino-gateway
      port:
        number: 8080
```

Now we should be able to access the gateway web UI via TLS with a valid
certificate:

![Gateway tls web UI](/img/gateway_tls_ui.png)

Now, we can connect to the gateway from our client tools using TLS. For example,
if using the Trino CLI:

```
$ trino --server https://trino-gateway.starburst-customer-success.com --user bob
trino> show catalogs;
 Catalog
---------
 system
 tpcds
 tpch
(3 rows)

Query 20220412_131551_00001_isuvu, FINISHED, 1 node
Splits: 4 total, 4 done (100.00%)
0.37 [0 rows, 0B] [0 rows/s, 0B/s]

trino>
```

# Conclusion

I hope this article proves useful for someone as I could not find much 
information on deploying Lyft's gateway on a kubernetes platform.

I did not cover how to deploy this gateway with end-to-end encryption
between the client, gateway, and backend Trino clusters. I hope to
cover this in a future article.
