# frozen_string_literal: true

require 'bundler/setup'

APP_RAKEFILE = File.expand_path('spec/dummy/Rakefile', __dir__)
load 'rails/tasks/engine.rake'
load 'rails/tasks/statistics.rake'

require 'bundler/gem_tasks'

require 'rubocop/rake_task'
RuboCop::RakeTask.new

require 'bundler/audit/task'
Bundler::Audit::Task.new

desc 'Run Brakeman security scanner'
task brakeman: :environment do
  require 'brakeman'
  result = Brakeman.run(app_path: '.', print_report: true, pager: false)
  exit(result.filtered_warnings.empty? ? 0 : 1)
end
