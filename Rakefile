namespace :rubyspec do
  task :run_and_record_failures do
    sh 'DISABLE_BREAKPOINTS=1 bin/my.rb ./mspec/bin/mspec-tag ./rubyspec/language/ -- --int-spec'
  end

  task :run_passing do
    sh 'DISABLE_BREAKPOINTS=1 ./mspec/bin/mspec -t bin/my.rb ./rubyspec/language/ -- --excl-tag=fails'
  end
end
