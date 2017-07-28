---
layout: post
title:  "A word of warning about Docker for Mac"
date:   2017-07-26 21:53:36 -0700
categories: docker mac osx macos vm virtualization
---

I've recently taken up a bit of a Docker crusade at work.

Because our office develops applications in multiple languages across various
platforms, we have developers from .NET backgrounds using Windows machines, and
developers from the Rails world using Macbooks.

In order to allow developers from any platform to contribute, I have been
Dockerizing new applications. Docker provides our cross-platform team two main
benefits:
- Environment standardization
  - Both Windows and MacOS hosts can use the same Docker VM, meaning all
    dependencies and configurations can be identical across environments
- Application isolation
  - Developers need to run multiple applications simultaneously. With Docker,
    we can prevent things like dependency or port conflicts
