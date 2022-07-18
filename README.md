# Kubito Traefik Cloudflared (Argo Tunnel) Source IP

This repository contains a Traefik plugin which can be used when you are running a Cloudflared (Argo Tunnel) instance. It is primarily made to be used in a Kubernetes environment, which means it is not tested in other environments.

## Introduction

When Traefik runs behind Cloudflared, especially in case of a Kubernetes cluster which uses Traefik as a load balancer, it is unable to get the real source IP from which a request is coming from. The `X-Real-Ip` header, which Traefik uses instead of the usual `X-Forwarded-For` header, is always set to the IP of the Cloudflared service.

This plugin solves the issue by overwriting the `X-Real-Ip` header, as well the `X-Forwarded-For` header, to the value of the `Cf-Connecting-Ip` which is the real source IP and is set by the Cloudflared instance on each request.

The Docker image inside this repository extends the official Traefik image by simply adding this plugin as a local plugin.

## Usage

The recommended way to use this plugin without the need to setup the Traefik Pilot on your environment, is to run it with the custom Docker image which extends Traefik by adding the plugin as a local plugin inside the container.

After the container runs, it contains the plugin and can be referenced with:

```bash
--experimental.localPlugins.cloudflared-source-ip.moduleName=github.com/kubitodev/traefik-cloudflared-source-ip
```

Then, it can be used in a middleware object, for example in Kubernetes:

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: cloudflared-source-ip
  namespace: traefik-system
spec:
  plugin:
    cloudflared-source-ip:
      excludednets:
        - "1.1.1.1/24"
```

## Installing with Helm

There is a helm chart available as well. Check [the ArtifactHub page](https://artifacthub.io/packages/helm/kubitodev/traefik-cloudflared-source-ip) for more details. It uses the custom Docker image which extends Traefik, and allows you to run it without the need to setup Traefik Pilot.

> IMPORTANT: If you are not deploying the chart with the optional official Traefik subchart dependency, make sure you use the `kubitodev/traefik-cloudflared-source-ip` Docker image for your Traefik deployment before you use the chart. Also, the usage of Argo Tunnels with Traefik requires you to generate a Cloudflare certificate and enable Full (strict) mode for SSL/TLS. More information can be found in the Configuration section of this page.

And after that, you can inject the middleware in an ingress route and follow the Traefik logs to see what happens upon executing a request. The source IP will be the first one that is not included in any of the CIDRs passed as the `excludedNets` parameter. The evaluation of the `X-Forwarded-For` or `Cf-Connecting-Ip` IPs will go from the last to the first one.

You can simply leave the `excludedNets` parameter as default if you wish.

## Useful configuration tips

### Generating the SSL certificate (required)

Since the tunnel works with CNAME records, you will need to point the deployed instance of Cloudflared to Traefik's load balancer service which is your ingress controller. The catch is, you can't use your own TLS certificates because of how Cloudflared works with Traefik, so you'll have to generate the certificates via the Cloudflare dashboard. The good thing is, they last 15 years.

First, go to the [SSL/TLS Dashboard](https://dash.cloudflare.com/?to=/:account/:zone/ssl-tls) for your domain. Then, in the `Overview` tab, set the mode to `Full (strict)`. This means that it will require a mutual TLS connection between Cloudflare and the client (your Traefik instance). Then, go to the `Origin Server` tab, and click on `Create certificate`. Once there, choose the `Use my private key and CSR` option. Open a terminal and generate a CSR and Key with:

```bash
openssl req -new -newkey rsa:2048 -nodes -keyout tls.key -out tls.csr
```

Fill in the required fields, but most importantly set the `FDQN` value to your root domain, for example `example.com`. Copy the generated `tls.csr` and paste it in the input box on the Cloudflare page. Now, in the `Hostnames` field, enter your domain and a wildcard for subdomains, like `example.com` and `*.example.com`.

Finally, click on `Create`, and then download the generated certificate. Once you have it downloaded, rename it from `cert.pem` to `tls.crt`. Save the `tls.crt` and the previously generated `tls.key` as you will need them for creating the secret yourself, or for using them with this chart if you choose so. The secret will be used for creating a default TLS store in Traefik.

Go in the `SSL/TLS` dashboard again and select the `Edge Certificates` tab. Enable the `Always use HTTPS` option and that's it on the Cloudflare side.

### Getting the Argo Tunnel ID (required)

- Start by downloading and installing the lightweight Cloudflare Tunnel daemon, `cloudflared`. You can find it [here](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/).

- Once installed, you can use the tunnel login command in `cloudflared` to obtain a certificate:

```bash
cloudflared tunnel login
```

- Create the tunnel with:

```bash
cloudflared tunnel create example-tunnel
```

- Associate your tunnel with a CNAME DNS Record

```bash
cloudflared tunnel route dns example-tunnel tunnel.example.com
```

- The tunnel configuration can be found in `~/.cloudflared/<TUNNEL_ID>.json`. You will need it for creating a secret/configmap when deploying the Cloudflared instance on your cluster.

Now, when you want to create a new subdomain, just point it as a CNAME to the tunnel record, and it will be routed automatically!

For more information, check the [official guide](https://developers.cloudflare.com/cloudflare-one/tutorials/many-cfd-one-tunnel/).

### Setting up the Argo Tunnel ingress options

To use the tunnel with Traefik, you need to configure the ingress settings. As cloudflared works with CNAMEs, you want to set a wildcard hostname for the service, and set the origin request setting to be the root domain that you are configuring this for. Also, you need to point the service to the secure port (443) of the Traefik load balancer service. Here is an example configuration:

```yaml
cloudflared:
  ingress:
    - hostname: "*.example.com"
      service: https://traefik.traefik-system.svc.cluster.local:443
      originRequest:
        originServerName: example.com
    - service: http_status:404
```

### Using the new default TLS store

The TLS store that is deployed with this chart uses the secret that contains the generated Cloudflare TLS certificate and key. To use it, just set the `tls: {}` field in your ingress route objects, and it will automatically choose to serve that certificate. Example:

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: example-ingressroute
spec:
  ...
  tls: {}
```


## License

Copyright &copy; 2022 Kubito

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
