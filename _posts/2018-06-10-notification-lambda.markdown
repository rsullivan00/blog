---
layout: post
title:  "Adding a Contact Form to Your Static Site"
date:   2018-06-09
categories: notifications aws lambda
---

Want to add a contact form to your simple static site? Here's how to do it with
near-zero costs, easy setup, and easy teardown if you want to replace the backend
with your own server-based application.

## Architecture

In short, we want:

1. A simple form a user can enter their email, phone, name, and a short message
2. Notifications when that form is submitted

To keep this simple and cheap, we will use the [Serverless](https://serverless.com/) 
framework to build out the infrastructure on Amazon's Web Services.

{%
  include figure.html
  url="/assets/serverless_notification.svg"
  caption="The architecture of our form handler"
%}

## Creating the Serverless Infrastructure

Serverless can create a project skeleton for us with:

```bash
serverless create --template aws-nodejs --path contact-lambda
```

Update your generated `serverless.yml` with the minimal AWS configuration we 
need for SNS notifications.

```yaml
# serverless.yml

service: contact-lambda

provider:
  name: aws
  runtime: nodejs6.10
  region: us-east-1

  iamRoleStatements:
    - Effect: Allow
      Action:
        - 'sns:Publish'
      Resource:
        Ref: ContactTopic

functions:
  Notify:
    handler: handler.notify
    memorySize: 128 # Reduce costs by minimizing resources allocated to lambda
    events:
      - http:
          path: notify
          method: post
          cors: true
    environment:
      TOPIC_ARN:
        Ref: ContactTopic

resources:
  Resources:
    ContactTopic:
      Type: AWS::SNS::Topic
      Properties:
        DisplayName: 'Contact Topic'
        TopicName: 'contact-topic'
        Subscription:
          # Add any emails or SMS numbers you would like notified
          - Endpoint: 'me@mysite.com'
            Protocol: 'email'
          - Endpoint: '5555555555'
            Protocol: 'sms'
```

Run `serverless deploy` to create your infrastructure. Make note of the POST
endpoint created:

```bash
$ sls deploy
Serverless: Packaging service...
Serverless: Excluding development dependencies...
Serverless: Uploading CloudFormation file to S3...
Serverless: Uploading artifacts...
Serverless: Uploading service .zip file to S3 (58.06 KB)...
Serverless: Validating template...
Serverless: Updating Stack...
Serverless: Checking Stack update progress...
..........
Serverless: Stack update finished...
Service Information
service: contact-lambda
stage: dev
region: us-west-2
stack: contact-lambda-dev
api keys:
  None
endpoints:
  POST - https://abcdefghi1.execute-api.us-east-1.amazonaws.com/dev/notify
functions:
  Notify: contact-lambda-dev-Notify
Serverless: Removing old service versions...
```

Now that we have the infrastructure in place, let's modify the Lambda handler
to send notifications when forms are submitted.

## Form handling

We want our handler to handle form submissions like

```html
<!-- test.html -->
<form
  action='https://abcdefghi1.execute-api.us-east-1.amazonaws.com/dev/notify'
  method='post'
>
  <label>
    Email
    <input type='text' name='email'>
  </label>
  <label>
    Name
    <input type='text' name='name'>
  </label>
  <label>
    Message
    <input type='text' name='message'>
  </label>
  <label>
    Phone
    <input type='text' name='phone'>
  </label>
  <input type='submit'>
</form>
```

We'll use a couple Node packages to simplify form parsing.

```bash
yarn add html-entities qs
```

Our handler is then responsible for sending a SNS message to our notification
topic.

```js
// handler.js
'use strict'

const AWS = require('aws-sdk')
const sns = new AWS.SNS()
const qs = require('qs')
const Entities = require('html-entities').XmlEntities
const entities = new Entities()

const formKeys = ['email', 'message', 'phone', 'name']

module.exports.notify = (event, context, callback) => {
  const body = qs.parse(event.body)
  const message = formKeys
    .map(key => `${key}:${entities.decode(body[key])}`)
    .join('\n')
  sns.publish(
    {
      Message: message,
      Subject: 'New contact form submitted',
      TopicArn: process.env.TOPIC_ARN
    },
    (err, result) =>
      callback(null, {
        statusCode: err ? '500' : '201',
        body: err ? err.message : JSON.stringify(result),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      })
  )
}
```

And that's it! Redeploy with `serverless deploy`, and you can start sending 
notifications when forms are submitted.

## The result

When your topic and subscriptions are created, you will receive an email or SMS
message from AWS asking you to confirm your subscription to the
notification topic.

{%
  include figure.html
  url="/assets/subscription_confirmation.png"
  caption="SNS automatically sends a subscription confirmation message"
%}

Confirm your subscription, and any form submissions will send you a notification
with the form contents.

{%
  include figure.html
  url="/assets/submitted_contact_form.png"
  caption="Submitted forms will be distributed to all subscribers"
%}

Not pretty, but perfect for internal notifications, especially since subscriptions
are automatically managed for you! You form handler can also be extended with
Slack or other application integrations.
