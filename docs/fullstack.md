# Component development

Turbo, Stimulus, Tailwind CSS and DaisyUI are available in the base application. The optional Rails template adds ViewComponent, RSpec component helpers and a development-only Lookbook at `/lookbook`.

## Install

From the project root, run the template and restart the development server.

```sh
bin/rails app:template LOCATION=./bin/fullstack.rb
bin/dev
```

For Docker development, run the template in the web container. Rebuild the image to include the updated bundle.

```sh
docker compose run --rm web ./bin/rails app:template LOCATION=./bin/fullstack.rb
docker compose up --build
```

Answer `y` to generate an example button with a Stimulus controller, a Lookbook preview and a rendering spec. Run its spec with `bundle exec rspec spec/components/example/component_spec.rb`. Open the example in Lookbook to try the button. Answer `n` to install the component tooling alone.

## Add components

Put component classes and ERB templates in `app/components`. Register any component Stimulus controllers in `app/javascript/controllers/index.js`. The customer-facing Tailwind stylesheet scans the component directory.

Put preview classes in `spec/components/previews` and tag rendering specs with `type: :component`.
