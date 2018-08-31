---
layout: post
title:  "Docker SSH configurations for development"
date:   2018-08-30
categories: docker ssh docker-compose
---

In a [previous post about Docker for Mac]({% post_url 2017-08-10-docker-for-mac %}), 
I described a way to make SSH keys available inside of Docker containers--here's 
a simpler approach with a few advantages over my previous suggestion. Docker 
volumes allow you to link directories from your host machine to the Docker 
container, even if the host location is outside of the directory with your 
`docker-compose.yml`.

## SSH volume configuration

Expose your local `~/.ssh` directory as a read-only directory in your Docker 
container with

```yaml
# docker-compose.yml
version: '3'
services:
  web:
    volumes:
    - .:/myapp
    - ~/.ssh:/root/.ssh:ro
    ...
```

Code running in your Docker container will now have read-only copies of your ssh
directory available, meaning your `id_rsa` will be used for installing `git+ssh`
dependencies, and any aliases you have defined in your `~/.ssh/config` will be
respected.

Because the files are mounted as a volume, each user can rely on the same base
Docker image, but configure their volume to mount files that are relevant for 
their usage.

## Other applications of volumes

### AWS Credentials

The same approach can be used for other types of credentials--I've used the same
pattern for the [AWS CLI](https://aws.amazon.com/cli/) by mapping `~/.aws` to
`/root/.aws` as a read-only volume. This allows most AWS tools, from the CLI, to
the Python Boto3 SDK, to the Elixir ExAws library to access your credentials
and AWS profiles with minimal or no configuration.

### Persistent dependencies

For dependencies installed by package managers, such as Ruby's [Bundler](https://bundler.io/)
and Elixir's [Mix](https://hexdocs.pm/mix/Mix.Tasks.Deps.html), I was previously
building dependencies into the images built with a `Dockerfile`. This process 
allows us to reuse Docker images with exact package versions already installed, 
but requires rebuilding the image when any package is added or updated. 

In this case, our application dependencies are installed through a single
command, either `bundle ` or `mix deps.get`, which must be rerun to build the
Docker image. `Dockerfile`s execute each `RUN` command line by line and caches 
the filesystem after each line. Docker executes from the previous cached step,
so it must reinstall _all_ packages from your package manager, not just the
modified packages.

Alternatively, we can create a persistent volume in Docker Compose to store our
installed dependencies, but not bake them into the image itself.

```yaml
# docker-compose.yml
version: '3'
volumes:
  _deps:
  bundle:
services:
  web:
    volumes:
    - _deps:/myapp/_deps
    - bundle:/bundle
```

Now, to update dependencies, we run a single `docker-compose run web bundle` or
`docker-compose run web mix deps.get` to update our Ruby or Elixir dependencies,
and only changes are installed.
