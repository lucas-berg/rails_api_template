# API documentation

Swagger UI is available at `/api-docs` and serves `/api-docs/openapi.yaml`. The local development credentials default to `username` and `password`. In production set both `SWAGGER_USERNAME` and `SWAGGER_PASSWORD` to enable the documentation routes.

The contract is generated from the JSON request specs. Start with an empty output file so removed operations disappear from the specification.

```sh
mkdir -p tmp
rm -f tmp/openapi-local.yaml
OPENAPI=1 OPENAPI_OUTPUT=tmp/openapi-local.yaml bundle exec rspec spec/requests/api --order defined &&
  cp tmp/openapi-local.yaml doc/openapi.yaml
```

Commit the resulting specification alongside interface changes. CI generates a fresh copy and compares it with the committed file.
