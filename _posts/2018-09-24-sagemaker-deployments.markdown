---
layout: post
title:  "The State of Sagemaker Automation"
date:   2018-09-24
categories: aws sagemaker deployment python automation
---


About a year ago, Amazon publicly released Sagemaker, its platform for training 
and managing machine learning models. Sagemaker has an appealing value 
proposition--users can train models and tune hyperparameters using on-demand EC2 
instances with a variety of hardware options, and models are stored for 
deployment to endpoints with IAM access control. On my team, we chose Sagemaker 
for managing our training and deployment of a text classification algorithm 
using a Tensorflow neural network. Here are some of the things I learned 
while creating an automated path to production.

## Training and Tuning

The Sagemaker documentation and tutorials provide simplistic examples using
iPython notebooks manually edited and run on AWS. While this is great as a 
launching point, the web iPython editor has some bad ergonomics we wanted to 
avoid--namely, a lack of reviewable changes tracked in git and a slow feedback 
loop.

The [SageMaker Python SDK](https://github.com/aws/sagemaker-python-sdk) lets us
script training and hyperparameter tuning into Python scripts. The scripts can 
be run locally, and the SDK can run the computationally expensive training or 
tuning on EC2 instances. It even provides a very high-level [Estimator API for creating
Tensorflow-based models](https://sagemaker.readthedocs.io/en/v1.11.0/sagemaker.tensorflow.html).

Be aware that the default behavior of the SDK is to wait for each step in your 
script to complete--steps that can take on the order of hours for training. You
are able to disable the waiting behavior, and you can design your scripts to be
resumed at a later point. We instead found the easiest approach to be to set up 
a `t2.micro` EC2 instance and work from there, backgrounding processes if we 
wanted them to run for a long time.

## Deployments

The simplified workflow we worked toward for our deployments is:

1. Developers and data scientists run scripts to train/experiment with any model 
  in our Dev AWS account.
2. Once we are happy the performance of a new model, the model is deployed to QA 
  for smoke testing.
3. If the model passes, it is promoted to production.

Once a model is trained, tuned, and evaluated as step (1), we have a single QA
endpoint where we can run some simple stability tests. The SageMaker SDK _does_
provide the ability to deploy models to an HTTP endpoint with a simple 
`deploy()` call. Unfortunately, `deploy()` [does not support updating existing 
endpoints](https://github.com/aws/sagemaker-python-sdk/issues/101), our target
use case.

### Cross-account issues

## Going forward


