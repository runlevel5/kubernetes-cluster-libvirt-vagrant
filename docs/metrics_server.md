# How to install Metrics Server

1. `cd vagrant && vagrant ssh kmaster`
2. `wget https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.6/components.yaml && mv components.yaml metrics-server.yaml`
3. `sed -i 's/amd64/ppc64le/g' metrics-server.yaml` if your box is ppc64le
4. Add following arguments into deployment block of `metric-servers` inside the yaml file:

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: metrics-server
  namespace: kube-system
  labels:
    k8s-app: metrics-server

...
        args:
          - --cert-dir=/tmp
          - --secure-port=4443
          - --kubelet-insecure-tls # ADD THIS
          - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname # ADD THIS
```
4. `kubectl apply -f  metrics-server.yaml` and wait for few minutes
5. Verify with `kubectl top nodes`, you should see node stats
