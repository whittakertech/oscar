# frozen_string_literal: true

require 'rails/generators'
require 'whittaker_tech/oscar'

# `rails generate whittaker_tech:oscar:install` — copies the taxonomy
# config initializer template into the host app. Oscar has no models,
# migrations, or routes of its own to install; the taxonomy is entirely
# host-model configuration (see docs/design.md).
class WhittakerTech::Oscar::InstallGenerator < Rails::Generators::Base
  source_root File.join(__dir__, 'templates')

  def banner
    say_status :whittaker_tech_oscar, 'Installing WhittakerTech::Oscar engine', :green
  end

  def create_initializer
    template 'oscar.rb.tt', 'config/initializers/oscar.rb'
  end

  def show_post_install_message
    say "\nWhittakerTech::Oscar installed.", :green
    say 'Edit config/initializers/oscar.rb to declare your taxonomy — see docs/design.md.'
  end
end
