# radiusd-ldap 

This is an Alpine Linux based container image for Kubernetes, that provides [radiusd](https://github.com/FreeRADIUS/freeradius-server)
prepared for the [Google Secure LDAP](https://support.google.com/a/answer/9048516?hl=en) backend (requires Google Workspace enterprise licence).
For further readings please see [here](https://support.google.com/a/answer/9089736?hl=en#zippy=%2Cfreeradius).

## Prerequisites

Extract the certificates you received from Google and rename them to `ldap-client.crt` and `ldap-client.key`.
Also ensure the following environment variables are set correctly:

```shell
export ACCESS_ALLOWED_CIDR="0.0.0.0/0" # This is the CIDR that is allowed to connect to your radiusd
export BASE_DOMAIN="example"           # Your Google Workspace domain name without TLD
export DOMAIN_EXT="com"                # Domain extension (TLD)
export GOOGLE_LDAP_USER="Username"     # Google Secure LDAP
export GOOGLE_LDAP_PASS="Password"     # client credentials
export SHARED_SECRET="$(openssl rand -hex 32)" # Shared secret for access to the radiusd
export GOOGLE_LDAP_TLS_CERT_FILE="/full/path/to/ldap-client.crt" # Google Secure LDAP client
export GOOGLE_LDAP_TLS_KEY_FILE="/full/path/to/ldap-client.key"  # certificate and key
```

**Note**:
The Makefile depends on the primary one found [here](https://github.com/fff0x/images/tree/master/%40include).

## Deployment

Optional: Spin up a local Kubernetes cluster with `k3d` (k3s in docker):

```shell
k3d cluster create radius-test -p "1812:1812/udp@loadbalancer" --k3s-server-arg "--no-deploy=traefik,metrics-server"
export KUBECONFIG=$(k3d kubeconfig write radius-test)
```

And use the provided Makefile to deploy the Kubernetes application:

```shell
sed -i "s|ACCESS_ALLOWED_CIDR|$ACCESS_ALLOWED_CIDR|g" manifests/02-ConfigMap.yaml
sed -i "s|BASE_DOMAIN|$BASE_DOMAIN|g" manifests/02-ConfigMap.yaml
sed -i "s|DOMAIN_EXTENSION|$DOMAIN_EXT|g" manifests/02-ConfigMap.yaml
make deploy-k8s
```

Afterward set up some secrets:

```shell
kubectl create secret tls -n radius google-tls-client-secret \
  --cert=$GOOGLE_LDAP_TLS_CERT_FILE \
  --key=$GOOGLE_LDAP_TLS_KEY_FILE

kubectl create secret generic -n radius google-client-secret \
  --from-literal=google_ldap_username="${GOOGLE_LDAP_USER}" \
  --from-literal=google_ldap_password="${GOOGLE_LDAP_PASS}"

kubectl create secret generic -n radius freeradius-shared-secret \
  --from-literal=shared_secret="${SHARED_SECRET}"
```

**Note**:
The Kubernetes manifests optionally provides an IngressRoute configuration for the Traefik v2 ingress controller.
See `manifests/traefikv2` and [this](https://github.com/k3s-io/k3s/issues/1141) for the current status of
Traefik integration in k3s.

## Debug

Fetch logs, execute a shell or test connection to the freeradius server:

```shell
make logs-k8s

make shell-k8s

radtest 'USERNAME' 'PASSWORD' 127.0.0.1 10 "$SHARED_SECRET"
```

## Uninstall

```shell
make clean-k8s

k3d cluster delete radius-test
```

## Credits:

All credits goes to [Hans Cornelis](https://github.com/hacor)!
Many thanks for the initial [idea](https://github.com/hacor/unifi-freeradius-ldap).
