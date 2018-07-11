require 'rails/generators/rails/app/app_generator'

module ReactiveRuby
  class TestAppGenerator < ::Rails::Generators::Base
    def self.source_paths
      paths = self.superclass.source_paths
      paths << File.expand_path('../templates', __FILE__)
      paths.flatten
    end

    def remove_existing_app
      remove_dir(test_app_path) if File.directory?(test_app_path)
    end

    def generate_test_app
      opts = options.dup
      opts[:database] = 'sqlite3' if opts[:database].blank?
      opts[:force] = true
      opts[:skip_bundle] = true

      puts "Generating Test Rails Application..."
      invoke ::Rails::Generators::AppGenerator,
        [ File.expand_path(test_app_path, destination_root) ], opts
    end

    def configure_test_app
      template 'boot.rb.erb', "#{test_app_path}/config/boot.rb", force: true
      template 'test_application.rb.erb', "#{test_app_path}/config/application.rb", force: true
      template 'assets/javascripts/test_application.rb',
        "#{test_app_path}/app/assets/javascripts/application.rb", force: true
      template 'assets/javascripts/server_rendering.js',
               "#{test_app_path}/app/assets/javascripts/server_rendering.js", force: true
      template 'assets/javascripts/components.rb',
        "#{test_app_path}/app/views/components.rb", force: true
      template 'views/components/hello_world.rb',
        "#{test_app_path}/app/views/components/hello_world.rb", force: true
      template 'views/components/todo.rb',
        "#{test_app_path}/app/views/components/todo.rb", force: true
      template 'views/layouts/test_layout.html.erb',
        "#{test_app_path}/app/views/layouts/test_layout.html.erb", force: true
      template 'views/layouts/test_layout.html.erb',
        "#{test_app_path}/app/views/layouts/explicit_layout.html.erb", force: true
    end

    def clean_superfluous_files
      inside test_app_path do
        remove_file '.gitignore'
        remove_file 'doc'
        remove_file 'Gemfile'
        remove_file 'lib/tasks'
        remove_file 'app/assets/images/rails.png'
        remove_file 'app/assets/javascripts/application.js'
        remove_file 'public/index.html'
        remove_file 'public/robots.txt'
        remove_file 'README.rdoc'
        remove_file 'test'
        remove_file 'vendor'
        remove_file 'spec'
      end
    end

    def configure_opal_rspec
      inject_into_file "#{test_app_path}/config/application.rb",
        after: /class Application < Rails::Application/, verbose: true do
        %Q[
    config.opal.method_missing = true
    config.opal.optimized_operators = true
    config.opal.arity_check = false
    config.opal.const_missing = true
    config.opal.dynamic_require_severity = :ignore
    config.opal.enable_specs = true
    config.opal.spec_location = 'spec-opal'
    config.hyperloop.auto_config = false

    config.react.server_renderer_options = {
      files: ["server_rendering.js"]
    }
    config.react.server_renderer_directories = ["/app/assets/javascripts"]
]
      end
    end

    protected

    def application_definition
      @application_definition ||= begin
                                    test_application_contents
                                  end
    end
    alias :store_application_definition! :application_definition

    private

    def test_app_path
      'spec/test_app'
    end

    def test_application_path
      File.expand_path("#{test_app_path}/config/application.rb",
                       destination_root)
    end

    def test_application_contents
      return unless File.exists?(test_application_path) && !options[:pretend]
      contents = File.read(test_application_path)
      contents[(contents.index("module #{module_name}"))..-1]
    end

    def module_name
      'TestApp'
    end

    def gemfile_path
      '../../../../Gemfile'
    end
  end
end
