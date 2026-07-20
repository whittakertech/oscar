# frozen_string_literal: true

# Rails Engine definition for WhittakerTech::Oscar.
#
# Responsibilities:
# - Isolates the +WhittakerTech::Oscar+ namespace from the host application.
# - Deduplicates migration paths so the engine's +db/migrate+ directory is not
#   registered twice when the dummy app resolves to the same path.
class WhittakerTech::Oscar::Engine < Rails::Engine
  isolate_namespace WhittakerTech::Oscar

  initializer 'oscar.migrations' do |app|
    engine_paths = config.paths['db/migrate'].expanded
    existing_paths = ActiveRecord::Migrator.migrations_paths.map { |p| File.expand_path(p) }

    engine_paths.each do |expanded_path|
      unless existing_paths.include?(expanded_path)
        app.config.paths['db/migrate'] << expanded_path
        ActiveRecord::Migrator.migrations_paths << expanded_path
      end
    end
  end

  config.time_zone = 'UTC'
  config.active_record.default_timezone = :utc
end
