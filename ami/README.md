# Chatbot Amazon Machine Image (AMI)

<https://github.com/lucasrod16/chatbot/issues/1>

## Build the AMI

```shell
aws sso login
```

```shell
packer init .
packer fmt .
packer validate .
packer build .
```
