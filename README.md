# CloudFormation CLI commands
- [CloudFormation CLI commands](#cloudformation-cli-commands)
  - [describe-stacks](#describe-stacks)
  - [create-stack](#create-stack)
    - [create-stack](#create-stack-1)
    - [wait stack-create-complete](#wait-stack-create-complete)
  - [delete-stack](#delete-stack)
    - [delete-stack](#delete-stack-1)
    - [stack-delete-complete](#stack-delete-complete)
  - [stack-update](#stack-update)
    - [stack-update](#stack-update-1)
    - [stack-update-complete](#stack-update-complete)
- [References](#references)

## describe-stacks

```
aws cloudformation describe-stacks \
--query 'Stacks[].StackName'
```

## create-stack
### create-stack

EC2 example

```
aws cloudformation create-stack \
--stack-name ${CFN_STACK_NAME} \
--template-body file://$(pwd)/${CFN_TEMPLATE_FILE} \
--parameters \
ParameterKey=Prefix,ParameterValue=${PREFIX} \
ParameterKey=TestMyClientIp,ParameterValue=${SSH_CLIENT_IP} \
ParameterKey=TestMyKeyPairName,ParameterValue=${KEY_PAIR_NAME}
```

### wait stack-create-complete

```
aws cloudformation wait stack-create-complete \
--stack-name ${CFN_STACK_NAME} 
```

## delete-stack
### delete-stack

```
aws cloudformation delete-stack \
--stack-name ${CFN_STACK_NAME}
```

### stack-delete-complete

```
aws cloudformation wait stack-delete-complete \
--stack-name ${CFN_STACK_NAME}
```

## stack-update 
### stack-update

Exapmle

```
aws cloudformation update-stack
--stack-name ${CFN_STACK_NAME} \
--template-body file://$(pwd)/${CFN_TEMPLATE_FILE} \
```

### stack-update-complete

```
aws cloudformation stack-update-complete \
--stack-name ${CFN_STACK_NAME}
```

# References

AWS CLI Command References > cloudformation
https://awscli.amazonaws.com/v2/documentation/api/latest/reference/cloudformation/index.html
