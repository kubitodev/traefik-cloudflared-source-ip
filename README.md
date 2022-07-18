# Kubito Traefik Cloudflared (Argo Tunnel) Source IP

This repository contains a Traefik plugin which can be used when you are running a Cloudflared (Argo Tunnel) instance. It is primarily made to be used in a Kubernetes environment, which means it is not tested in other environments.

## Introduction

When Traefik runs behind Cloudflared, especially in case of a Kubernetes cluster which uses Traefik as a load balancer, it is unable to get the real source IP from which a request is coming from. The `X-Real-Ip` header, which Traefik uses instead of the usual `X-Forwarded-For` header, is always set to the IP of the Cloudflared service.

This plugin solves the issue by overwriting the `X-Real-Ip` header, as well the `X-Forwarded-For` header, to the value of the `Cf-Connecting-Ip` which is the real source IP and is set by the Cloudflared instance on each request.

The Docker image inside this repository extends the official Traefik image by simply adding this plugin as a local plugin.

## Installing with Helm

There is a helm chart available as well. Check [the ArtifactHub page](https://artifacthub.io/packages/helm/kubitodev/traefik-cloudflared-source-ip) for more details. It uses the custom Docker image which extends Traefik, and allows you to run it without the need to setup Traefik Pilot.

> IMPORTANT: If you are not deploying the chart with the optional official Traefik subchart dependency, make sure you use the `kubitodev/traefik-cloudflared-source-ip` Docker image for your Traefik deployment before you use the chart.

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

And after that, you can inject the middleware in an ingress route and follow the Traefik logs to see what happens upon executing a request.

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
