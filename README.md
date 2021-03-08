# radiusd-ldap 

This is an Alpine Linux based container image for Kubernetes, that provides [radiusd](https://github.com/FreeRADIUS/freeradius-server)
prepared for the [Google Secure LDAP](https://support.google.com/a/answer/9048516?hl=en) backend (requires Google Workspace enterprise licence).
For further readings please see [here](https://support.google.com/a/answer/9089736?hl=en#zippy=%2Cfreeradius).

**Note**:
Optionally you can use the provided Makefile to deploy and manage the Kubernetes application,
but it depends on a primary one found [here](https://github.com/fff0x/images/tree/master/%40include).

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
## Deployment

Optional: Spin up a local Kubernetes cluster:

Using `k3s`

```shell
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 --secrets-encryption --no-deploy traefik
```

or `k3d` (k3s in docker).

```shell
k3d cluster create radius-test -p "1812:1812/udp@loadbalancer" --k3s-server-arg "--no-deploy=traefik"
export KUBECONFIG=$(k3d kubeconfig write radius-test)
```

Set your variables and deploy the Kubernetes manifests:

```shell
sed -i "s|ACCESS_ALLOWED_CIDR|$ACCESS_ALLOWED_CIDR|g" manifests/02-ConfigMap.yaml
sed -i "s|BASE_DOMAIN|$BASE_DOMAIN|g" manifests/02-ConfigMap.yaml
sed -i "s|DOMAIN_EXTENSION|$DOMAIN_EXT|g" manifests/02-ConfigMap.yaml

kubectl create -f manifests/
```

Afterwards create the required secrets:

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

Without verbose logging, the container logs are pretty useless, so edit the deployment and uncomment
the **command** override, enabling argument '-X'.

First of all double check that the Google LDAP service is **enabled** (state: on) if you encounter problems,
like CrashLoops or weird LDAP plugin messages like "Bind credentials incorrect: Invalid credentials".

The message **TLS certificate verification: Error, self signed certificate** is not an fatal error.
`radiusd` does not use SNI while connecting to the Google server and as an result, the certificate does not match.

Fetch current container logs:

```shell
kubectl logs -n "radius" $(shell kubectl get pod -n "radius" -lapp="freeradius" -o name) -f
```

Execute a shell:

```shell
kubectl exec -n "radius" -ti $(shell kubectl get pod -n "radius" -lapp="freeradius" -o name) -- /bin/sh
```

Test connection to the freeradius server. This requires the `radtest` binary on your local machine,
also ensure that you IP address match the provided CIDR in "$ACCESS_ALLOWED_CIDR".

radtest 'GOOGLE_USERNAME_OR_EMAIL_ADDRESS' 'GOOGLE_USER_PASSWORD' SERVER_IP 10 "$SHARED_SECRET"
```

## Uninstall

```shell
kubectl delete -f manifests/
```

## Credits:

All credits goes to [Hans Cornelis](https://github.com/hacor)!
Many thanks for the initial [idea](https://github.com/hacor/unifi-freeradius-ldap).
