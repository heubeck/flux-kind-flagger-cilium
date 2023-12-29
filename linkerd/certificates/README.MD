# Certificate generation process

* [Linkerd docs](https://linkerd.io/2.14/tasks/generate-certificates/)
* [Step tool](https://smallstep.com/cli/)

## Root CA

```shell
# Trust anchor certificate
step certificate create root.linkerd.cluster.local ca.crt ca.key --profile root-ca --no-password --insecure --not-after 876000h
```

```shell
# Create ConfigMap holding the trust anchor certificate
kubectl create configmap -n linkerd linkerd-identity-trust-roots --from-file=ca-bundle.crt=ca.crt --dry-run=client -o yaml > linkerd-identity-trust-roots.yaml
```

### Identity issuer

```shell
# Issuer certificate and key
step certificate create identity.linkerd.cluster.local issuer.crt issuer.key --profile intermediate-ca --not-after 876000h --no-password --insecure --ca ca.crt --ca-key ca.key
```

```shell
# Create Secret holding identity issuer certificate
kubectl create secret generic -n linkerd linkerd-identity-issuer --from-file=tls.crt=issuer.crt --from-file=tls.key=issuer.key --from-file=ca.crt=ca.crt -o yaml --dry-run=client > linkerd-identity-issuer.yaml
```

### Proxy injector

```shell
# Proxy injector certificate and key
step certificate create linkerd-proxy-injector.linkerd.svc injector.crt injector.key --kty=RSA --profile leaf --not-after 876000h --no-password --insecure --ca ca.crt --ca-key ca.key
```

```shell
# Create tls Secret holding the injector certificate
kubectl create secret tls -n linkerd linkerd-proxy-injector-k8s-tls --cert=injector.crt --key=injector.key -o yaml --dry-run=client > linkerd-proxy-injector-k8s-tls.yaml
```

### Policy validator

```shell
# Policy validator certificate and key
step certificate create linkerd-policy-validator.linkerd.svc policy.crt policy.key --kty=RSA --profile leaf --not-after 876000h --no-password --insecure --ca ca.crt --ca-key ca.key
```

```shell
# Create tls Secret holding the injector certificate
kubectl create secret tls -n linkerd linkerd-policy-validator-k8s-tls --cert=policy.crt --key=policy.key -o yaml --dry-run=client > linkerd-policy-validator-k8s-tls.yaml
```

### SP validator

```shell
# SP validator certificate and key
step certificate create linkerd-sp-validator.linkerd.svc sp.crt sp.key --kty=RSA --profile leaf --not-after 876000h --no-password --insecure --ca ca.crt --ca-key ca.key
```

```shell
# Create tls Secret holding the injector certificate
kubectl create secret tls -n linkerd linkerd-sp-validator-k8s-tls --cert=sp.crt --key=sp.key -o yaml --dry-run=client > linkerd-sp-validator-k8s-tls.yaml
```

### Viz extension

```shell
# Tap injector certificate and key
step certificate create tap-injector.linkerd-viz.svc tap-injector.crt tap-injector.key --kty=RSA --profile leaf --not-after 876000h --no-password --insecure --ca ca.crt --ca-key ca.key
```

```shell
# create tls Secret holding the tap injector certificate
kubectl create secret tls -n linkerd-viz tap-injector-k8s-tls --cert=tap-injector.crt --key=tap-injector.key -o yaml --dry-run=client > tap-injector-k8s-tls.yaml
```

```shell
# Tap certificate and key
step certificate create tap.linkerd-viz.svc tap.crt tap.key --kty=RSA --profile leaf --not-after 876000h --no-password --insecure --ca ca.crt --ca-key ca.key
```

```shell
# create tls Secret holding the tap certificate
kubectl create secret tls -n linkerd-viz tap-k8s-tls --cert=tap.crt --key=tap.key -o yaml --dry-run=client > tap-k8s-tls.yaml
```
