---
layout: post
title:  "Adding a Contact Form to Your Static Site"
date:   2018-06-09
categories: notifications aws lambda
---

Want to add a contact form to your simple static site? Here's how.

## Architecture

In short, we want:

1. A simple form a user can enter their email, phone, name, and a short message
2. Notifications when that form is submitted

To keep this simple and cheap, we will use the [Serverless](https://serverless.com/) 
framework to build out the infrastructure on Amazon's Web Services.

![Serverless Architecture Diagram](/assets/serverless_notification.svg)
