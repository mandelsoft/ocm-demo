# Simple Demo for OCM based Lifecycle

This project provides a simple web application, an appropriate helm chart and an OCM based installation package using the TOI installer framework. It can be built, published and deployed using an OCM component version.

The default OCM repository dor the component is
`ghcr.io/mandelsoft/ocm`.

The component name is `mandelsoft.org/demo/helmdemo`, floating version `1.0.0-dev`

## Preconditions

A precondition is an installed OCM CLI and the *docker* service.

**ATTENTION:** As long as the required features are still under development you
should use the branch `routingslip` in [`github.com/mandelsoft/ocm`](https://github.com/mandelsoft/ocm).
Fetch this branch and call `make install`, which will install 
the OCM CLI in the bin folder of your Go workspace.

If you want to work with OCM repositories, you should create
an `.ocmconfig` file in your HOME directory:

**~/.ocmconfig:** 
```yaml
type: generic.config.ocm.software/v1
configurations:
  - type: credentials.config.ocm.software
    repositories:
    - repository:
        type: DockerConfig/v1
        dockerConfigFile: "~/.docker/config.json"
        propagateConsumerIdentity: true
```

It tells the OCM CLI to reuse your docker configuration
to read the credentials required to access OCI registry based
OCM repositories. Please set the correct location of your docker
config file.

Your local environment for using the Makefile can be configured
via environment variables:

```bash
export PROVIDER= <your intended provider name, default mandelsoft.org>
export GITHUBORG=<your-org if you are using GitHub as pacakge repository, default mandelsoft>
export OCMREPO=<your ocm repository to publish the component (<your-oci-repo>/<path-to-ocm-repo>), default ghcr.io/$(GITHUBORG)/ocm>
```

Additionally, the variable `TARGETREPO` is used for various purposes, it should not be set in the environment.

## Operations

All operations are covered by the `Makefile` provided by the project.
This demo will execute make targets for the command executions
to offer as short as possible command lines.

The Makefile provides a complete project setup for building the
content and all live-cycle operations for the provided component
version.

The used OCM commands executed behind the scenes are shown in
the output. Feel free to copy them and play with the arguments
to execute different flavors.

All temporary generated data will be generated in the `gen`
folder of the project. Additionally, the folder `local` is used
to generate non-volatile data like keys or installation
configurations. These folders are excluded by `.gitignore`

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

Afterwards, you can have a look into the content of the generated component version with

```bash
make describe
```

to examine the component version's resource structure, or

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
      KUBECONFIG: (( read("~/k8s/CLUSTERS/ocmdemo","text") ))
```

If you use a garden cluster, you can enable DNS support from Gardener, you just
have to enter a flat sub-domain of the ingress domain of your
cluster. If you require 
a deeper DNS name, or a sub-somain of another domain configured
for your cluster, you can additionally enable the garden DNS
option.

```bash
TARGETREPO=... make toi-install
```

If you omit the `TARGETREPO` your default push location is used (specifying `OCMREPO` or `GITHUBORG`). Please be aware, that it is not possible to deploy directly from the CTF file, because an image in an OCI registry is required.

With

```bash
TARGETREPO=... make toi-uninstall
```

you can remove the deployment, again.

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

For preparation, you need a key pair for signing. With the 
command 

```bash
[PROVIDER=...] make keys
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

### Signing

To sign your component, you need a keeypair for your organization. The same keys already used for the routing slip can be used:

```bash
[PROVIDER=...] make keys
```

Now you are read for signing. A component version may carry an
arbitrary number of signatures. Therefore, every signature has
a name, typically the name of the providing organization or any other identity, for example a mail address.

The provided Makefile uses the provider. Som to sign your component just call:

```bash
[PROVIDER=...] make sign
```

It signs your local CTF, to sign directly in a repository just
precede your call with your desired TARGETREPO:

```bash
TARGETREPO=... [PROVIDER=...] make sign
```

Similarily it ispossible to verify a signature with

```bash
[TARGETREPO=...] [PROVIDER=...] make verify
```

To verify the original version of this demo provided in
the OCM repository `ghcr.io/mandelsoft/ocm`, the following command can be used:

```bash
make keys verify-orig
```

It uses the public key coming with this git repository content.

The signature covers only signature-relevant data fields. The
routing slip is implemented as volatile label, and can be added
or extended after a component version has been signed.

This can be demonstrated, by adding [routing slip](#routing-slips) enties after signing the component. Afterwards, the signature(s) can stll successfully be verified.

### Resetting your version

If you want to overwrite your published version with the content
of your CTF, for example to reset your routing slip, you can
just use

```bash
make force-push
```

### Static config in `.ocmconfig`

Static key definitions can easily be added to your
ocm confiuration file `~/.ocmconfig`:

```yaml
type: generic.config.ocm.software/v1
configurations:
  - type: credentials.config.ocm.software
    repositories:
    - repository:
        type: DockerConfig/v1
        dockerConfigFile: "~/.docker/config.json"
        propagateConsumerIdentity: true

  - type: keys.config.ocm.software
    privateKeys:
      mandelsoft.org:
        path: ~/.ocm/keys/mandelsoft.org

```