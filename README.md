Download `sitecopy2`:
```shell
curl -sH 'private-token: REDACTED_GITLAB_TOKEN' 'https://gitlab.r99.no/api/v4/projects/10/repository/files/sitecopy?ref=master' | jq -r .content | base64 -d > sitecopy2 && chmod +x sitecopy2
```
Official Documentation: https://servebolt.atlassian.net/wiki/spaces/SER/pages/2691423174664/New+Sitecopy
