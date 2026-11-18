# frozen_string_literal: true

declared_gems = Bundler.definition.dependencies.map(&:name)
gem 'view_component', '~> 4.0' unless declared_gems.include?('view_component')
gem 'lookbook', '~> 2.3', group: :development unless declared_gems.include?('lookbook')

environment 'config.view_component.previews.paths << Rails.root.join("spec/components/previews").to_s',
            env: 'development'
route "mount Lookbook::Engine, at: '/lookbook' if Rails.env.development?"

append_to_file 'app/assets/tailwind/users.css', %(@source "../../components";\n), force: false

create_file 'spec/support/view_component.rb', <<~SOURCE, skip: true
  # frozen_string_literal: true

  require 'view_component/test_helpers'
  require 'view_component/system_test_helpers'

  RSpec.configure do |config|
    config.include ViewComponent::TestHelpers, type: :component
    config.include ViewComponent::SystemTestHelpers, type: :component
    config.include Capybara::DSL, type: :component, js: true
    config.include Capybara::RSpecMatchers, type: :component
  end
SOURCE

if yes?('Add an example component, preview and spec? [y/n]')
  create_file 'app/components/example/component.rb', <<~SOURCE, skip: true
    # frozen_string_literal: true

    module Example
      class Component < ViewComponent::Base
      end
    end
  SOURCE

  create_file 'app/components/example/component.html.erb', <<~SOURCE, skip: true
    <button type="button" class="btn btn-primary" data-controller="example--component"
            data-action="click->example--component#toggle" aria-pressed="false">
      Toggle selection
    </button>
  SOURCE

  create_file 'app/components/example/component_controller.js', <<~SOURCE, skip: true
    import { Controller } from '@hotwired/stimulus'

    export default class extends Controller {
      toggle() {
        const pressed = this.element.getAttribute('aria-pressed') === 'true'
        this.element.setAttribute('aria-pressed', String(!pressed))
      }
    }
  SOURCE

  append_to_file 'app/javascript/controllers/index.js', <<~SOURCE, force: false

    import ExampleComponentController from '../../components/example/component_controller'
    application.register('example--component', ExampleComponentController)
  SOURCE

  create_file 'spec/components/previews/example/component_preview.rb', <<~SOURCE, skip: true
    # frozen_string_literal: true

    module Example
      class ComponentPreview < ViewComponent::Preview
        def standard
          render Example::Component.new
        end
      end
    end
  SOURCE

  create_file 'spec/components/example/component_spec.rb', <<~SOURCE, skip: true
    # frozen_string_literal: true

    require 'rails_helper'

    RSpec.describe Example::Component, type: :component do
      it 'renders a selectable button' do
        render_inline(described_class.new)

        expect(Capybara.string(rendered_content)).to have_css(
          'button[data-controller="example--component"][aria-pressed="false"]', text: 'Toggle selection'
        )
      end
    end
  SOURCE
end
