---
layout: post
title:  "A word of warning about Docker for Mac"
date:   2017-07-26 21:53:36 -0700
categories: docker mac osx macos vm virtualization docker-compose
---

I've recently taken up a bit of a Docker crusade at work.

Because our office develops applications in multiple languages across various
platforms, we have developers from .NET backgrounds using Windows machines, and
developers from the Rails world using Macbooks.

In order to allow developers from any platform to contribute, I have been
Dockerizing our applications. Docker provides our cross-platform team two main
benefits:
- Environment standardization
  - Both Windows and MacOS hosts can use the same Docker VM, meaning all
    dependencies and configurations can be identical across environments
  - Easy docker setup with `docker-compose` reduces overhead for onboarding new
    team members
- Application isolation
  - Developers need to run multiple applications simultaneously. With Docker,
    we can prevent things like dependency or port conflicts

After a few months developing applications with Docker on Mac, I've found
some issues that any new adopters should be aware of.

### Slow I/O and Execution

With any virtualization, we expect to see some amount of slowdown. On Docker for
Mac, however, issues with I/O and slow application execution can cause the
development experience to range from a 2x slowdown to a completely unusable
100x or more slowdown, when used with some build tools.

Docker on Mac has [documented issues with slow reads and writes on mounted
volumes](https://github.com/docker/for-mac/issues/77).

### TODO: Add more details about slow IO

Running tests should be a generally I/O-light task. In two Rails applications,
test execution time varies as follows:

&nbsp; | Default Volume | Cached Volume | Delegated Volume | No Volume | Native Execution
:--- | ---: | ---: | ---: | ---: | ---:
App A | 74.6s | 57.8s | 59.1s | 36.9s | 18.5s
App B | 19.5s | 16.6s | 16.5s | 11.1s | 6.7s

You can see that the recent Docker changes *do* increase performance, but even
Docker with no file syncing (the "No Volume" column) takes about twice as long
to execute tests.

### SSH Key Management

For cloning private dependencies or sshing into application servers, developers
often need ssh keys to be available from within a Docker container.

With Docker on Linux, users [mount their `.ssh` directory as a
volume on a Docker container](https://stackoverflow.com/questions/34932490/inject-hosts-ssh-keys-into-docker-machine-with-docker-compose)
or [use SSH agent forwarding](https://gist.github.com/d11wtq/8699521) to allow
the container private key access.

Docker for Mac SSH agent forwarding is [on the roadmap](https://github.com/docker/for-mac/issues/483),
but does not yet have an elegant solution. I've worked around the issue by
adding the key and ssh configuration to the container at build time.

- Add a `docker/` directory to your application
- Add any necessary ssh configuration to `docker/ssh_config`:

```
# docker/ssh_config
# Add any convenience SSH configuration
Host staging
  Hostname 8.8.8.8

# Use the key for ssh commands
IdentityFile /root/.ssh/id_rsa
```

- Add `docker/id_rsa` to your `.gitignore` or similar for your version control.
- Copy your `~/.ssh/id_rsa` to `docker/id_rsa`
- Build your container with the following additions to your Dockerfile:

```docker
# Dockerfile
RUN mkdir -p /root/.ssh
ADD docker/ssh_config /root/.ssh/config
ADD docker/id_rsa /root/.ssh/id_rsa
RUN chmod 600 /root/.ssh/id_rsa
```

**Warning:** This will add your private key to a layer in your Docker image. Do
not use this approach if you will share you Docker images.

### Unfreeable Disk Usage

### Takeaway

While Docker has many benefits, Docker for Mac's slowness is a huge killer of
developer productivity. For some less I/O intensive applications, Docker for Mac
may still be a valid option, but it is not the universal virtualization solution
I had hoped it would be.
