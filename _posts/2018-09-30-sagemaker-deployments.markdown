---
layout: post
title:  "Getting Sagemaker Models to Production"
date:   2018-09-30
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

1. Developers and data scientists run scripts to train/experiment with any model in our Dev AWS account.
2. Once we are happy the performance of a new model, the model is deployed to QA for smoke testing.
3. If the model passes, it is promoted to production.

Once a model is trained, tuned, and evaluated as step (1), we have a single QA
endpoint where we can run some simple stability tests. The SageMaker SDK _does_
provide the ability to deploy models to an HTTP endpoint with a simple 
`deploy()` call. Unfortunately, `deploy()` [does not support updating existing 
endpoints](https://github.com/aws/sagemaker-python-sdk/issues/101), our target
use case.

It is possible to work around this restriction relatively easily by creating a 
new SageMaker `EndpointConfiguration` with a lower level API. This worked 
initially for (2), our QA deployment, but ran into issues with our workflow step
(3). 

### Cross-account issues

Our production is isolated into its own AWS account, and the SageMaker SDK
makes the implicit assumption in many areas that it is operating within a single 
AWS account. 

When a SageMaker model is trained, a gzipped file of model artifacts is dumped
in an S3 bucket to be loaded when the model is deployed. In order to workaroudn 
the cross-account restrictions, I created a script using `boto3` to 

1. Move the artifacts to a bucket in the new account
2. Create a model in the new account with matching configurations
3. Create a new endpoint configuration with the new model
4. Update the existing endpoint with the new endpoint configuration

Below is the model promotion script. It makes some assumptions about the 
CloudFormation stack setup in each environment, since we are using 
CloudFormation for our infrastructure management.

```python
# promote_model.py
import boto3
import botocore
import click
import re
from datetime import datetime


@click.command()
@click.option('--model-name', help='The model that should be promoted')
@click.option(
    '--source-profile',
    default='myapp-qa',
    help='Profile name in your AWS CLI configuration for the deployment source'
)
@click.option(
    '--target-profile',
    help='Profile name in your AWS CLI configuration for the deployment target'
)
@click.option(
    '--stage',
    type=click.Choice(['qa', 'production']),
    help='The target stage')
@click.option(
    '--target-stack-name', help='Target environment CloudFormation stack')
def promote_model(model_name, source_profile, target_profile, stage,
                  target_stack_name):
    naming_prefix = 'myapp-{}'.format(stage)
    target_stack_name = target_stack_name or naming_prefix
    target_endpoint_name = naming_prefix
    source_session = boto3.session.Session(profile_name=source_profile)
    target_session = boto3.session.Session(profile_name=target_profile)
    stack_outputs = get_stack_outputs(target_session, target_stack_name)
    destination_bucket = stack_outputs['MyAppBucketName']
    source_model = find_model(source_session.client('sagemaker'), model_name)
    target_sagemaker = target_session.client('sagemaker')
    source_container = source_model['PrimaryContainer']
    source_dir_s3_path = source_container['Environment'][
        'SAGEMAKER_SUBMIT_DIRECTORY']
    source_dir_bucket = re.match('(^s3://.+?)/', source_dir_s3_path).group(1)
    target_model_s3_path = copy_s3_object_to_bucket(
        source_container['ModelDataUrl'], destination_bucket, target_session)
    target_dir_s3_path = copy_s3_object_to_bucket(
        source_dir_s3_path, destination_bucket, target_session)
    model_created_timestamp = datetime.utcfromtimestamp(
        source_model['CreationTime'].timestamp()).strftime('%Y-%m-%d-%H-%M')
    new_model_name = '{}-model-{}'.format(naming_prefix,
                                          model_created_timestamp)
    endpoint_config_name = '{}-config-{}'.format(naming_prefix,
                                                 model_created_timestamp)
    if not find_model(target_sagemaker, new_model_name):
        target_sagemaker.create_model(
            ModelName=new_model_name,
            ExecutionRoleArn=stack_outputs['MyAppSagemakerRoleArn'],
            PrimaryContainer={
                **source_container, 'Environment': {
                    **source_container['Environment'], 'SAGEMAKER_SUBMIT_DIRECTORY':
                    target_dir_s3_path
                },
                'ModelDataUrl': target_model_s3_path
            })

    if not find_endpoint_config(target_sagemaker, endpoint_config_name):
        target_sagemaker.create_endpoint_config(
            EndpointConfigName=endpoint_config_name,
            ProductionVariants=[{
                'VariantName': 'AllTraffic',
                'ModelName': new_model_name,
                'InitialInstanceCount': 1,
                'InstanceType': 'ml.t2.medium'
            }])

    if find_endpoint(target_sagemaker, target_endpoint_name):
        target_sagemaker.update_endpoint(
            EndpointName=target_endpoint_name,
            EndpointConfigName=endpoint_config_name)
    else:
        target_sagemaker.create_endpoint(
            EndpointName=target_endpoint_name,
            EndpointConfigName=endpoint_config_name)


def get_stack_outputs(session, stack_name):
    cloudformation = session.client('cloudformation')
    result = cloudformation.describe_stacks(StackName=stack_name)
    return {
        output['OutputKey']: output['OutputValue']
        for output in result['Stacks'][0]['Outputs']
    }


def find_model(sagemaker_client, model_name):
    try:
        return sagemaker_client.describe_model(ModelName=model_name)
    except botocore.exceptions.ClientError:
        return None


def find_endpoint(sagemaker_client, endpoint_name):
    try:
        return sagemaker_client.describe_endpoint(EndpointName=endpoint_name)
    except botocore.exceptions.ClientError:
        return None


def find_endpoint_config(sagemaker_client, endpoint_config_name):
    try:
        return sagemaker_client.describe_endpoint_config(
            EndpointConfigName=endpoint_config_name)
    except botocore.exceptions.ClientError:
        return None


def copy_s3_object_to_bucket(s3_source, bucket, session):
    s3_destination = re.sub('^s3://.+?/', 's3://{}/'.format(bucket), s3_source)
    copy_s3_object(s3_source, s3_destination, session)
    return s3_destination


def copy_s3_object(s3_source, s3_destination, session):
    """
    Moves files bewtween `s3://bucket/path/file.ext` locations
    """

    def _extract_s3_objects(s3_path):
        match = re.match('^s3://(.+?)/(.+)', s3_path)
        return match.groups()

    source_bucket, source_key = _extract_s3_objects(s3_source)
    destination_bucket, destination_key = _extract_s3_objects(s3_destination)
    return session.client('s3').copy_object(
        CopySource={
            'Bucket': source_bucket,
            'Key': source_key
        },
        Bucket=destination_bucket,
        Key=destination_key)


if __name__ == '__main__':
promote_model()
```

The script can be run with

```bash
python promote_model.py \
  --stage=qa \
  --source-profile=source-aws-profile \
  --target-profile=qa-aws-profile \
  --model-name=sagemaker-tensorflow-2018-10-01-01-15-23-007
```

Which will create a model called `myapp-qa-model-2018-10-01-15-23-00` and deploy
it to the `myapp-qa` endpoint in the target account. Each resource is created if
it doesn't exist, and the script can be rerun safely.

## Going forward

We are now at a point where we can deploy evaluated models to our production 
environment. There are still many things to improve, but we are now exploring
the best approaches to retraining our SageMaker models with user feedback.

