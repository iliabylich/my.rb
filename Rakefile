namespace :rubyspec do
  env = 'PATCH_EVAL=1 DISABLE_TRACES=1 DISABLE_BREAKPOINTS=1'

  def each_spec
    Dir['./rubyspec/language/**/*_spec.rb'].sort.each do |f|
      yield f
    rescue Exception => e
      puts "#{f} failed with #{e}"
    end
  end

  task :run_and_record_failures do
    sh 'rm -rf tags'
    each_spec do |f|
      sh "#{env} bin/my.rb ./mspec/bin/mspec-tag #{f} -- --int-spec"
    end
  end

  task :run_passing do
    each_spec do |f|
      sh "#{env} ./mspec/bin/mspec -t bin/my.rb #{f} -- --excl-tag=fails"
    end
  end
end
