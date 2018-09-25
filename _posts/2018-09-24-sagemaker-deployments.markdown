---
layout: post
title:  "The State of Sagemaker Deployments"
date:   2018-09-24
categories: aws sagemaker deployment python
---


About a year ago, Amazon publicly released Sagemaker, its platform for training 
and managing machine learning models. Sagemaker has an appealing value 
proposition--users can train models and tune hyperparameters using on-demand EC2 
instances with a variety of hardware options, and models are stored for 
deployment to endpoints with IAM access control. On my team, we chose Sagemaker 
for managing our training and deployment of a text classification algorithm 
using a Tensorflow neural network. Here are some of the things I learned along 
the way.

## Automating training 

The Sagemaker documentation and tutorials provide simplistic examples using
iPython notebooks manually edited and run on AWS. I prefer to automate as much 
as possible from my local system to minimize the feedback loop and allow for 
code changes to be reviewed in pull requests.

## Cross-account deployments
