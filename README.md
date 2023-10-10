## New Sitecopy:
Download `sitecopy2`:
```shell
curl -sH 'private-token: REDACTED_GITLAB_TOKEN' 'https://gitlab.r99.no/api/v4/projects/10/repository/files/sitecopy2?ref=master' | jq -r .content | base64 -d > sitecopy2
```

## Old Sitecopy:
see https://gitlab.r99.no/tools/sitecopy/wikis/home
