require 'spec_helper'

RSpec.describe 'VM' do
  def evaluate_using_custom_vm(code)
    input, output = IO.pipe
    pid = fork do
      input.close
      argv = ['-e', code]#, '--debug']
      Object.send(:remove_const, :ARGV)
      Object.const_set(:ARGV, argv)
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
      require_relative('../main.rb')
      output.close
    end
    Process.wait(pid)
    input.read_nonblock(1_000)
  end

  def evalate_using_mri(code)
    real_stdout, $stdout = $stdout, StringIO.new
    eval(code)
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
    assert_evaluates_like_mri('a = true; p(a ? 1 : 2)')
  end

  it 'handles unless branching' do
    assert_evaluates_like_mri('a = false; p(a ? 1 : 2)')
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
    assert_evaluates_like_mri(<<-RUBY)
      %i[Set SortedSet].each { |const_name| Object.send(:remove_const, const_name) }
      $LOADED_FEATURES.reject! { |f| f =~ Regexp.new(Regexp.escape("/set.rb")) }
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
end
