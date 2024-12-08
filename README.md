# chatbot

Deploy a self-hosted Retrieval-Augmented Generation (RAG) chatbot using [Ollama](https://ollama.com/) and [Open WebUI](https://openwebui.com/).

## Deploy

```shell
aws sso login
```

```shell
./deploy.sh
```

## Teardown

```shell
terraform destroy --auto-approve
```
