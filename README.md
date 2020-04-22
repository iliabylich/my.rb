## Ruby executor

Blog post: https://ilyabylich.svbtle.com/evaluating-ruby-in-ruby

Requirements:

+ ruby 2.6.4

A Ruby-like executable is in the `bin/` directory:

```sh
$ bin/my.rb -e 'p 1 + 1'
2

$ echo 'p "I am a Ruby file"' > test.rb
$ bin/my.rb test.rb
"I am a Ruby file"
```

### Debug mode

You can turn off a few options to see what happens inside:

1. `-d` - enabled debug mode. Prints all frames and instructions.
2. `--debug-print-stack` - also prints a stack after each instruction.

If you have a ton of code it's possible to focus on a specific frame

```sh
$ bin/my.rb --debug-focus-on="<frame>" your-file.rb
```

`<frame>` must match the name of the frame (i.e. at least some part of its `pretty_name`). It's like a `grep` for internal state of the VM.

### Tests

To run a very naive and simple test suite run `rspec`.

To run RubySpec testsuite to `git submodule update --init` and run

```sh
$ rake rubyspec:run_passing
```

It will run all specs from `rubyspec/language`.

### Code structure

``` sh
# entry point, applies a few patches to MRI to handle require/eval on its own
bin/my.rb

# CLI interface, you can view it to check more command-line options
cli.rb

# an actual VM implementation
vm.rb

# a class that holds `execute_*` implementations of all instructions
executor.rb

vm
|- stack.rb # stack implementation
|- frame_stack.rb # frame stack implementation
|- iseq.rb # a wrapper for instruction sequence
|- locals.rb # an implementation of per-frame local variables
|- frames
  |- top_frame.rb
  |- class_frame.rb
  |- # ...
|- helpers
  |- categorized_arguments.rb # method/block arguments parser
  |- method_arguments.rb # method/block arguments handler (based on parser, does assignment and validation)
  |- method_definition_scope.rb # computes the scope where the constant must be defined
  |- backtrace_entry.rb # a wrapper around a single line in a backtrace

# a RubySpec testsuite. Only specs under rubyspec/language are used
rubyspec

# vendored MSpec (a testing frameword used by RubySpec test suite)
mspec

# a directory that lists all specs that are currently broken
tags
```

### Contributing

I don't expect any Pull Requests.
