namespace :rubyspec do
  task :run_and_record_failures do
    sh 'DISABLE_BREAKPOINTS=1 ../mspec/bin/mspec tag -t bin/my.rb ../rubyspec/language/'
  end

  task :run_passing do
    sh 'DISABLE_BREAKPOINTS=1 ../mspec/bin/mspec -t bin/my.rb ../rubyspec/language/ -- --excl-tag=fails'
  end
end
