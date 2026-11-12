desc "Run the full test suite with an 80% application line coverage requirement"
task :coverage do
  ENV["COVERAGE"] = "true"
  Rake::Task["test"].invoke
end
