require 'spec_helper'

RSpec.describe 'VM' do
  def evaluate_using_custom_vm(code, debug: false)
    input, output = IO.pipe
    pid = fork do
      input.close
      argv = ['-e', code, *(debug ? ['--debug'] : [])]
      Object.send(:remove_const, :ARGV)
      Object.const_set(:ARGV, argv)

      if !debug
        $real_stdout = $stdout
        $fake_stdout = output
        $stdout = $fake_stdout
        $stderr = $fake_stdout
        Binding.prepend(Module.new {
          def irb
            $stdout = $real_stdout
            super
          ensure
            $stdout = $fake_stdout
          end
        })
      end

      require_relative('../bin/my')
      output.close
    end
    Process.wait(pid)
    input.read_nonblock(1_000)
  end

  def evalate_using_mri(code)
    real_stdout, $stdout = $stdout, StringIO.new
    TOPLEVEL_BINDING.eval(code)
    $stdout.rewind
    $stdout.read
  ensure
    $stdout = real_stdout
  end

  def assert_evaluates_like_mri(code)
    expected = evalate_using_mri(code)
    actual = evaluate_using_custom_vm(code)

    expect(actual).to eq(expected)
  end

  it 'handles 2+2' do
    assert_evaluates_like_mri('p 2+2')
  end

  it 'handles method def' do
    assert_evaluates_like_mri('def m(a,b); a+b; end; p m(40, 2)')
  end

  it 'handles optargs' do
    assert_evaluates_like_mri('def m(a = 1, b = 2); [a, b]; end; p m()')
    assert_evaluates_like_mri('def m(a = 1, b = 2); [a, b]; end; p m(3, 4)')
  end

  it 'handles complex arguments' do
    assert_evaluates_like_mri(<<-RUBY)
      def m(a, (b, bb, *c,    d, dd),  f = 1,  g = 2 + 2, *h,      i,  (j, k),   l:,   m: 1, n: 2 + 2, o: 42, **p)
        [a,b,bb,c,d,dd,f,g,h,i,j,k,l,m,n,o]
      end

      p   m(1, [2, 2.2, 3, 4, 5, 5.5],   7,     8,         9, 10,  11, [12, 13], l: 11,      n: 12,    o: 13)
    RUBY
  end

  it 'handles if branching' do
    assert_evaluates_like_mri(<<-RUBY)
      a = true
      if a
        p 1
      else
        p 2
      end

      if a
        p 3
      end
    RUBY
  end

  it 'handles unless branching' do
    assert_evaluates_like_mri(<<-RUBY)
      a = false
      unless a
        p 1
      else
        p 2
      end

      unless a
        p 3
      end
    RUBY
  end

  it 'handles classes' do
    assert_evaluates_like_mri(<<-RUBY)
      module M
        def method_from_module
          'method_from_module'
        end
      end

      class A
        include M

        def test
          'test'
        end
      end

      p A.new.test
      p A.new.method_from_module
    RUBY
  end

  it 'handles Struct' do
    assert_evaluates_like_mri(<<-RUBY)
      require 'ostruct'
      o = OpenStruct.new(a: 1)
      o.b = 2
      p o
    RUBY
  end

  it 'handles Set' do
    assert_evaluates_like_mri(<<-'RUBY')
      %i[Set SortedSet].each { |const_name| Object.send(:remove_const, const_name) }
      $LOADED_FEATURES.reject! { |f| f =~ /\/set\.rb/ }
      require 'set'
      set = Set[1, 2, 3]
      p set
      set << 3
      set << 4
      p set
    RUBY
  end

  it 'supports blocks' do
    assert_evaluates_like_mri(<<-RUBY)
      p [1,2,3].each do |e|
        puts e
      end
    RUBY
  end

  it 'supports exceptions' do
    assert_evaluates_like_mri(<<-RUBY)
      b = 2
      begin
        a = 1
        raise 'err'
      rescue => e;
        c = 3
        p e
      else
        p 2
      ensure
        p 3
      end
      p 4
    RUBY

    assert_evaluates_like_mri(<<-RUBY)
      begin
        p 1
      rescue => e;
        p e
      else
        p 2
      ensure
        p 3
      end
    RUBY
  end

  it 'supports longjmp via return' do
    assert_evaluates_like_mri(<<-RUBY)
      def m
        [1, 10].each do |x|
          [2, 20].each do |y|
            [3, 30].each do |z|
              return [x,y,z]
            end
          end
        end
      end

      p m

      def m
        proc { return 10 }.call
      end

      p m
    RUBY
  end

  it 'can return values of C methods' do
    assert_evaluates_like_mri(<<-RUBY)
      def m
        self
      end

      p m
    RUBY
  end

  it 'can return values to C methods' do
    assert_evaluates_like_mri(<<-'RUBY')
      o = Object.new
      def o.to_s; "42"; end
      puts "100 + #{o}"
    RUBY
  end

  it 'handles masgn' do
    assert_evaluates_like_mri(<<-RUBY)
      a, *b, c = 1, 2, 3
      d, *e, f = 4, 5
      g, h, *i, j, k = 1
      p [a,b,c,d,e,f,g,h,i,j,k]
    RUBY
  end

  it 'handles loops' do
    assert_evaluates_like_mri(<<-RUBY)
      for i in [1,2,3,4,5] do
        p i
      end

      i = 0
      while i < 5
        p i
        i += 1
      end
    RUBY
  end

  it 'handles longjmp via next' do
    assert_evaluates_like_mri(<<-RUBY)
      x = [1,2,3].map do |e|
        begin
          if e == 2
            raise '2 is not allowed'
          end
          e
        rescue
          next 42
        end
      end

      p x
    RUBY
  end

  it 'can yield through multiple frames' do
    assert_evaluates_like_mri(<<-RUBY)
      def m
        tap do
          yield 10
          yield 20
        end
      end

      m { |value| p value }
    RUBY
  end

  it 'supports instance_eval' do
    assert_evaluates_like_mri(<<-RUBY)
      1.instance_eval { p self }
      Kernel.class_eval { p self }
      block = proc { p self }
      1.instance_eval(&block)
      Kernel.class_eval(&block)
    RUBY
  end
end
