class MSpecScript
  set :tags_patterns, [
                        [%r(rubyspec/), 'tags/'],
                        [/_spec.rb$/, '_tags.txt']
                      ]
end
