namespace :security do
  desc 'Run hourly security audit and write alerts into Messages'
  task audit: :environment do
    SecurityAuditJob.perform_now
    puts 'Security audit completed.'
  end
end
