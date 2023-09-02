# Simple Demo for OCM based Lifecycle

This project provides a simple web application, an appropriate helm chart and an OCM based installation package using the TOI installer framework. It can be built, published and deployed using an OCM component version.

The default OCM repository dor the component is
`ghcr.io/mandelsoft/ocm`.

The component name is `mandelsoft.org/demo/helmdemo`, floating version `1.0.0-dev`

## Preconditions

A precondition is an installed OCM CLI and the *docker* service.

your local environment can be configured via environment variables:

```bash
export PROVIDER= <your intended provider name, default mandelsoft.org>
export GITHUBORG=<your-org if you are using GitHub as pacakge repository, default mandelsoft>
export OCMREPO=<your ocm repository to publish the component (<your-oci-repo>/<path-to-ocm-repo>), default ghcr.io/$(GITHUBORG)/ocm>
```

the variable `TARGETREPO` is used for various purposes, it should not be set in the environment.

## Operations

All operations are covered by the `Makefile` provided by the project.
It also shows the appropriate OCM commands.

### Building

To build the application image with your local *docker* just use

```bash
make build
```

If you just want to create the CTF containing the component version for your application use

```bash
make ctf
```

The CTF contains all the required resources, including a multi-platform
image for your application.

Afterwards you can have a look into the content of the generated component version with

```bash
make describe
```

or

```bash
make descriptor
```

just to show the OCM component descriptor for the generated component version.

### Publishing

If you use a GitHub Package repository you could do this just by

```bash
GITHUBORG=<your-org> make push
```

It uses an OCM repository `ocm` in your organization's package repository `ghcr.io/&lt;your-org>/ocm.

If you want to use another OCM repository use

```bash
OCMREPO=<your-oci-repo>/<path-to-ocm-repo> make push
```

To examine the result in an OCM repository use

```bash
TARGETREPO=<your-oci-repo>/<path-to-ocm-repo> make describe
TARGETREPO=<your-oci-repo>/<path-to-ocm-repo> make descriptor
```

**Note:** If you want to set the `TARGETREPO` to your `OCMREPO` just set
`TARGETREPO=repo`.)

In this OCM repository you will also see, that the image resource now has
an additional global access and you wll find the image directly under
the repository base path of your OCM repository in the OCI registry.

**Remark:** If you use `ghcr.io` please don't forget to make the imported OCI repositories public using the GitHub UI.

### Transporting (optional)

After publishing the component version you can transport it to another OCM repository, for example by using

```bash
[OCMREPO=....] TARGETREPO=<your-oci-target-repo>/<path-to-ocm-repo> make transport
```

If you do not specify your local OCM repository the standard local/dev repository is used as source (`OCMREPO`). Basically, you could also push the CTF directly to your target repository.


### Installing

Finally, you can deploy the application into a kubernetes cluster using the provided installation package.

To do so, you need some configuration. To help you composing the required configuration files, the provided package offers some templates, which can be downloaded with

```bash
TARGETREPO=... make toi-config
```

It creates a folder `local/toi`with two configuration files:
- `TOICredentials`: credential settings
- `TOIParameters`: configuration values used by the helm chart.

Fill in the requested configuration parameters and the path to your cluster kubeconfig. The kubeconfig must be self-contained, because it is used inside an installation container.

**TOIParameters:**
```yaml
namespace: myechoserver
config:
  color: "#ff0000"             # text color
  title: "Request Information" # page title
ingress:
  enabled: true
  enableGardenDNS: true
  hosts:
    - host: mechoserver.<ingress-domain>
      paths:
        - path: /
          pathType: Prefix
```

**TOICredentials:**
```yaml
credentials:
  target:
    credentials:
      KUBECONFIG: (( read("~/k8s/CLUSTERS/ocmdemo") ))
```

If you use a garden cluster, you can enable DNS support from Gardener, you just
have to enter the ingress domain of your cluster.

```bash
TARGETREPO=... make toi-install
```

If you omit the `TARGETREPO` your default push location is used (specifying `OCMREPO` or `GITHUBORG`). Please be aware, that it is not possible to deploy directly from the CTF file, because an image in an OCI registry is required.

### Routing Slips

The component version used as delivery unit may have any number of routing slips.
A routing slip belongs to a dedicated provider and has an appropriate name, for
example `mandelsoft.org`. This provider owns a private key and publishes a public key.
With these keys the provider may add any process step information to the routing slip,
and a consumer can verify these entries. This can even be done after the component version
has been signed.

The transport system supports republishing an already existent component version with
modified non-signature relevant label entries or additional signatures. The routing slips are implemented on the
basis of such labels, therefore, they can incrementally be transported to a consumer
(or re-published by the provider and re-imported by the consumer).

With the command

```bash
[PROVIDER=...] ]make rs-keys
```

a key pair is generated under `local/keys` with the name of your intended provider.
Afterwards, it is possible to add entries for the routing slip of the provider using

```bash
[PROVIDER=...] COMMENT=<your commant to add> make rs-add
```

By default, the CTF file is modified. The makefile uses a standard entry type (`comment`)
here, but basically any other custom type is possible.

To examine your routing slip you can use 

```bash
make rs
```

After extending your routing slip you can re-publish your CTF
again with the commands show above, for example

```bash
OCMREPO=<your-oci-repo>/<path-to-ocm-repo> make push
```

If you want to apply the command to the component version in a repository, instead, just precede
the above commands with your `TARGETREPO` setting

```bash
[TARGETREPO=...] [PROVIDER=...] COMMENT=<your commant to add> make rs-add
[TARGETREPO=...] make rs
```

Now your consumer may import the re-published version again with
the transfer commands from above:

```bash
[OCMREPO=....] TARGETREPO=<your-oci-target-repo>/<path-to-ocm-repo> make transport
```

### Resetting your version

If you want to overwrite your published version with the content
of your CTF, for example to reset your routing slip, you can
just use

```bash
make force-push
```

