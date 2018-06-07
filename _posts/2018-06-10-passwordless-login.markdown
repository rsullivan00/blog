---
layout: post
title:  "Passwordless Logins in Phoenix"
date:   2017-08-10 21:53:36 -0700
categories: elixir phoenix login security passwords
---


Maybe you've seen the slick "Magic Link" login that Slack and other apps now
support: here's how you can securely support that flow in a Phoenix app.


## Why Passwordless?

Passwordless logins with emails are typically as, or more, secure than 
password-based authentication with email resets enabled, and is sufficiently
secure for most web apps. They also make login extremely simple for the user, and
you no longer have to worry about securely handling passwords.

If you are handling things like financial or medical data, you may want to consider a multi-factor
authentication scheme.

## The basic flow

1. A user wants to login, and submits their email `joe@bob.com`
2. Your application sends a short-lived login link (~15 minutes) to `job@bob.com`
3. The user clicks the link and is authenticated

## The Code

You probably already have a `User` model, complete with an `email` that
you want to allow access. If not, generate one with:

```sh
mix phoenix.gen.model User users email
```

The [Sans Password](https://github.com/promptworks/sans_password) helpers make
our implementation incredibly simple. Their [README](https://github.com/promptworks/sans_password/blob/master/README.md) and [demo app](https://github.com/promptworks/sans_password_demo) are 
extremely helpful; much of this section comes straight from those.

Add Sans Password as a dependency:

```elixir
# mix.exs
def deps do
  [{:sans_password, "~> 1.0.0-beta"}]
end
```

And add a basic `Guardian` module:

```elixir
# my_app/guardian.ex
defmodule MyApp.Guardian do
  @impl
  def deliver_magic_link(user, magic_token, _params) do
    user
    |> Mailer.magic_link_email(magic_token)
    |> Mailer.deliver_later
  end
end
```


