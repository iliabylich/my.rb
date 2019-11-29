task :rubyspec do
  code = Dir['../rubyspec/language/**/*_spec.rb']
          .map { |spec| "require_relative '#{spec}'" }
          .join("\n")

  File.write('tests.rb', "#{code}\n")

  sh 'cat tests.rb'

  sh '../mspec/bin/mspec -t bin/my.rb tests.rb'
ensure
  sh 'rm tests.rb'
end
