require File.expand_path('../boot', __FILE__)

require 'rails/all'
require 'net/http'

require File.expand_path('../../lib/exception_notification',  __FILE__)

if defined?(Bundler)
  ActiveSupport::Deprecation.silence do
    Bundler.require(:default, Rails.env)
  end
end


module SciRate
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += Dir["#{config.root}/lib/**/"]
    config.action_controller.permit_all_parameters = true

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de


    config.assets.paths << Rails.root.join('app', 'assets', 'flash')
    config.assets.paths << Rails.root.join('vendor', 'assets', 'fonts')

    config.action_mailer.default_url_options = { :host => Settings::HOST }

    config.active_job.queue_adapter = :delayed_job
  end
end
