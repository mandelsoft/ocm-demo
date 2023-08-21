# Simple Demo for OCM based Lifecycle

This project provides a simple web application, an appropriate helm chart and an OCM based installation package using the TOI installer framework. It can be built, published and deployed using an OCM component version.

The default OCM repository dor the component is
`ghcr.io/mandelsoft/ocm`.

The component name is `mandelsoft.org/demo/helmdemo`, version `1.0.0`

## Preconditions

A precondition is an installed OCM CLI and the *docker* service.

## Operations

All operations are covered by the `Makefile` provided by the project.
It also shows the approriate OCM commands.

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

for further usage you can put those settings into your environment:

```bash
export OCMREPO=...
export GITHUBORG=...
```
To examine the result in an OCM repository use

```bash
TARGETREPO=<your-oci-repo>/<path-to-ocm-repo> make describe
TARGETREPO=<your-oci-repo>/<path-to-ocm-repo> make descriptor
```

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

To do so, you need some configuration. To help you composing the required configuration files, the provided package offeres some templates, which can be downloaded with

```bash
TARGETREPO=... make toi-config
```

It creates a folder `local/toi`with two configuration files:
- `TOICredentials`: credential settings
- `TOIParameters`: configuration values used by the helm chart.

Fill in the requested configuration parameters and the path to your cluster kubeconfig. The kubeconfig must be self-contained, because it is used inside an installation container.

```bash
TARGETREPO=... make toi-install
```

If you omit the `TARGETREPO` your default push location is used (specifying `OCMREPO` or `GITHUBORG`). Please be aware, that it is not possible to deploy directly from the CTF file, because an image in an OCI registry is required.