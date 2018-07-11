require 'spec_helper'

if opal?
describe React::Component, type: :component do
  after(:each) do
    React::API.clear_component_class_cache
  end

  it 'defines component spec methods' do
    stub_const 'Foo', Class.new
    Foo.class_eval do
      include React::Component
      def initialize(native = nil)
      end

      def render
        React.create_element('div')
      end
    end

    # Class Methods
    expect(Foo).to respond_to('initial_state')
    expect(Foo).to respond_to('default_props')
    expect(Foo).to respond_to('prop_types')

    # Instance method
    expect(Foo.new).to respond_to('component_will_mount')
    expect(Foo.new).to respond_to('component_did_mount')
    expect(Foo.new).to respond_to('component_will_receive_props')
    expect(Foo.new).to respond_to('should_component_update?')
    expect(Foo.new).to respond_to('component_will_update')
    expect(Foo.new).to respond_to('component_did_update')
    expect(Foo.new).to respond_to('component_will_unmount')
  end

  describe 'Life Cycle' do
    let(:element_to_render) { React.create_element(Foo) }

    before(:each) do
      stub_const 'Foo', Class.new
      Foo.class_eval do
        include React::Component
        def render
          React.create_element('div') { 'lorem' }
        end
      end
    end

    it 'invokes `before_mount` registered methods when `componentWillMount()`' do
      Foo.class_eval do
        before_mount :bar, :bar2
        def bar; end
        def bar2; end
      end

      expect_any_instance_of(Foo).to receive(:bar)
      expect_any_instance_of(Foo).to receive(:bar2)

      React::Test::Utils.render_into_document(element_to_render)
    end

    it 'invokes `after_mount` registered methods when `componentDidMount()`' do
      Foo.class_eval do
        after_mount :bar3, :bar4
        def bar3; end
        def bar4; end
      end

      expect_any_instance_of(Foo).to receive(:bar3)
      expect_any_instance_of(Foo).to receive(:bar4)

      React::Test::Utils.render_into_document(element_to_render)
    end

    it 'allows multiple class declared life cycle hooker' do
      stub_const 'FooBar', Class.new
      Foo.class_eval do
        before_mount :bar
        def bar; end
      end

      FooBar.class_eval do
        include React::Component
        after_mount :bar2
        def bar2; end
        def render
          React.create_element('div') { 'lorem' }
        end
      end

      expect_any_instance_of(Foo).to receive(:bar)

      React::Test::Utils.render_into_document(element_to_render)
    end

    it 'allows block for life cycle callback' do
      Foo.class_eval do
        before_mount do
          set_state({ foo: "bar" })
        end
      end

      instance = React::Test::Utils.render_into_document(element_to_render)
      expect(instance.state[:foo]).to be('bar')
    end
  end

  describe 'New style setter & getter' do
    before(:each) do
      stub_const 'Foo', Class.new
      Foo.class_eval do
        include React::Component
        def render
          div { state.foo }
        end
      end
    end

    it 'implicitly will create a state variable when first written' do
      Foo.class_eval do
        before_mount do
          state.foo! 'bar'
        end
      end

      expect(Foo).to render_static_html('<div>bar</div>')
    end

    it 'allows kernal method names like "format" to be used as state variable names' do
      Foo.class_eval do
        before_mount do
          state.format! 'yes'
          state.foo! state.format
        end
      end

      expect(Foo).to render_static_html('<div>yes</div>')
    end

    it 'returns an observer with the bang method and no arguments' do
      Foo.class_eval do
        before_mount do
          state.foo!(state.baz!.class.name)
        end
      end

      expect(Foo).to render_static_html('<div>React::Observable</div>')
    end

    it 'returns the current value of a state when written' do
      Foo.class_eval do
        before_mount do
          state.baz! 'bar'
          state.foo!(state.baz!('pow'))
        end
      end

      expect(Foo).to render_static_html('<div>bar</div>')
    end

    it 'can access an explicitly defined state`' do
      Foo.class_eval do
        define_state foo: :bar
      end

      expect(Foo).to render_static_html('<div>bar</div>')
    end

  end

  describe 'State setter & getter' do
    let(:element_to_render) { React.create_element(Foo) }

    before(:each) do
      stub_const 'Foo', Class.new
      Foo.class_eval do
        include React::Component
        def render
          React.create_element('div') { 'lorem' }
        end
      end
    end

    it 'defines setter using `define_state`' do
      Foo.class_eval do
        define_state :foo
        before_mount :set_up
        def set_up
          mutate.foo 'bar'
        end
      end

      instance = React::Test::Utils.render_into_document(element_to_render)
      expect(instance.state.foo).to be('bar')
    end

    it 'defines init state by passing a block to `define_state`' do
      Foo.class_eval do
        define_state(:foo) { 10 }
      end

      instance = React::Test::Utils.render_into_document(element_to_render)
      expect(instance.state.foo).to be(10)
    end

    it 'defines getter using `define_state`' do
      Foo.class_eval do
        define_state(:foo) { 10 }
        before_mount :bump
        def bump
          mutate.foo(state.foo + 20)
        end
      end

      instance = React::Test::Utils.render_into_document(element_to_render)
      expect(instance.state.foo).to be(30)
    end

    it 'defines multiple state accessors by passing array to `define_state`' do
      Foo.class_eval do
        define_state :foo, :foo2
        before_mount :set_up
        def set_up
          mutate.foo 10
          mutate.foo2 20
        end
      end

      instance = React::Test::Utils.render_into_document(element_to_render)
      expect(instance.state.foo).to be(10)
      expect(instance.state.foo2).to be(20)
    end

    it 'invokes `define_state` multiple times to define states' do
      Foo.class_eval do
        define_state(:foo) { 30 }
        define_state(:foo2) { 40 }
      end

      instance = React::Test::Utils.render_into_document(element_to_render)
      expect(instance.state.foo).to be(30)
      expect(instance.state.foo2).to be(40)
    end

    it 'can initialize multiple state variables with a block' do
      Foo.class_eval do
        define_state(:foo, :foo2) { 30 }
      end

      instance = React::Test::Utils.render_into_document(element_to_render)
      expect(instance.state.foo).to be(30)
      expect(instance.state.foo2).to be(30)
    end

    it 'can mix multiple state variables with initializers and a block' do
      Foo.class_eval do
        define_state(:x, :y, foo: 1, bar: 2) {3}
      end
      instance = React::Test::Utils.render_into_document(element_to_render)
      expect(instance.state.x).to be(3)
      expect(instance.state.y).to be(3)
      expect(instance.state.foo).to be(1)
      expect(instance.state.bar).to be(2)
    end

    it 'gets state in render method' do
      Foo.class_eval do
        define_state(:foo) { 10 }
        def render
          React.create_element('div') { state.foo }
        end
      end

      instance = React::Test::Utils.render_into_document(element_to_render)
      expect(`#{instance.dom_node}.textContent`).to eq('10')
    end

    it 'supports original `setState` as `set_state` method' do
      Foo.class_eval do
        before_mount do
          self.set_state(foo: 'bar')
        end
      end

      instance = renderToDocument(Foo)
      expect(instance.state[:foo]).to be('bar')
    end

    it 'supports original `replaceState` as `set_state!` method' do
      Foo.class_eval do
        before_mount do
          set_state(foo: 'bar')
          set_state!(bar: 'lorem')
        end
      end

      element = renderToDocument(Foo)
      puts "*************************************************************************************"
      puts "element.state[:foo] = #{element.state[:foo]}"
      puts "element.state[:bar] = #{element.state[:bar]}"
      puts "*************************************************************************************"
      expect(element.state[:foo]).to be_nil
      expect(element.state[:bar]).to eq('lorem')
    end

    it 'supports original `state` method' do
      Foo.class_eval do
        before_mount do
          self.set_state(foo: 'bar')
        end

        def render
          div { self.state[:foo] }
        end
      end

      expect(Foo).to render_static_html('<div>bar</div>')
    end

    it 'transforms state getter to Ruby object' do
      Foo.class_eval do
        define_state :foo

        before_mount do
          mutate.foo [{a: "Hello"}]
        end

        def render
          div { state.foo[0][:a] }
        end
      end

      expect(Foo).to render_static_html('<div>Hello</div>')
    end
  end

  describe 'Props' do
    describe 'this.props could be accessed through `params` method' do
      before do
        stub_const 'Foo', Class.new
        Foo.class_eval do
          include React::Component
        end
      end

      it 'reads from parent passed properties through `params`' do
        Foo.class_eval do
          def render
            React.create_element('div') { params[:prop] }
          end
        end

        element = renderToDocument(Foo, prop: 'foobar')
        expect(`#{element.dom_node}.textContent`).to eq('foobar')
      end

      it 'accesses nested params as orignal Ruby object' do
        Foo.class_eval do
          def render
            React.create_element('div') { params[:prop][0][:foo] }
          end
        end

        element = renderToDocument(Foo, prop: [{foo: 10}])
        expect(`#{element.dom_node}.textContent`).to eq('10')
      end
    end

    describe 'Props Updating', v13_only: true do
      before do
        stub_const 'Foo', Class.new
        Foo.class_eval do
          include React::Component
        end
      end

      it 'supports original `setProps` as method `set_props`' do
        Foo.class_eval do
          def render
            React.create_element('div') { params[:foo] }
          end
        end

        element = renderToDocument(Foo, {foo: 10})
        element.set_props(foo: 20)
        expect(`#{element.dom_node}.innerHTML`).to eq('20')
      end

      it 'supports original `replaceProps` as method `set_props!`' do
        Foo.class_eval do
          def render
            React.create_element('div') { params[:foo] ? 'exist' : 'null' }
          end
        end

        instance = renderToDocument(Foo, {foo: 10})
        instance.set_props!(bar: 20)
        expect(`#{instance.dom_node}.innerHTML`).to eq('null')
      end
    end

    describe 'Prop validation' do
      before do
        stub_const 'Foo', Class.new
        Foo.class_eval do
          include React::Component
        end
      end

      it 'specifies validation rules using `params` class method' do
        Foo.class_eval do
          params do
            requires :foo, type: String
            optional :bar
          end
        end

        expect(Foo.prop_types).to have_key(:_componentValidator)
      end

      it 'logs error in warning if validation failed' do
        stub_const 'Lorem', Class.new
        Foo.class_eval do
          params do
            requires :foo
            requires :lorem, type: Lorem
            optional :bar, type: String
          end

          def render; div; end
        end

        %x{
          var log = [];
          var org_warn_console =  window.console.warn;
          var org_error_console = window.console.error;
          window.console.warn = window.console.error = function(str){log.push(str)}
        }
        renderToDocument(Foo, bar: 10, lorem: Lorem.new)
        `window.console.warn = org_warn_console; window.console.error = org_error_console;`
        expect(`log[0]`).to match(/Warning: Failed prop( type|Type): In component `Foo`\nRequired prop `foo` was not specified\nProvided prop `bar` could not be converted to String/)
      end

      it 'should not log anything if validation pass' do
        stub_const 'Lorem', Class.new
        Foo.class_eval do
          params do
            requires :foo
            requires :lorem, type: Lorem
            optional :bar, type: String
          end

          def render; div; end
        end

        %x{
          var log = [];
          var org_warn_console = window.console.warn;
          var org_error_console = window.console.error;
          window.console.warn = window.console.error = function(str){log.push(str)}
        }
        renderToDocument(Foo, foo: 10, bar: '10', lorem: Lorem.new)
        `window.console.warn = org_warn_console; window.console.error = org_error_console;`
        expect(`log`).to eq([])
      end
    end

    describe 'Default props' do
      it 'sets default props using validation helper' do
        stub_const 'Foo', Class.new
        Foo.class_eval do
          include React::Component
          params do
            optional :foo, default: 'foo'
            optional :bar, default: 'bar'
          end

          def render
            div { params[:foo] + '-' + params[:bar]}
          end
        end

        expect(Foo).to render_static_html('<div>lorem-bar</div>').with_params(foo: 'lorem')
        expect(Foo).to render_static_html('<div>foo-bar</div>')
      end
    end
  end

  describe 'Anonymous Component' do
    it "will not generate spurious warning messages" do
      foo = Class.new(React::Component::Base)
      foo.class_eval do
        def render; "hello" end
      end

      %x{
        var log = [];
        var org_warn_console = window.console.warn;
        var org_error_console = window.console.error;
        window.console.warn = window.console.error = function(str){log.push(str)}
      }
      renderToDocument(foo)
      `window.console.warn = org_warn_console; window.console.error = org_error_console;`
      expect(`log`).to eq([])
    end
  end

  describe 'Render Error Handling' do
    before(:each) do
      %x{
        window.test_log = [];
        window.org_warn_console = window.console.warn;
        window.org_error_console = window.console.error;
        window.console.warn = window.console.error = function(str){window.test_log.push(str)}
      }
    end
    it "will generate a message if render returns something other than an Element or a String" do
      foo = Class.new(React::Component::Base)
      foo.class_eval do
        def render; Hash.new; end
      end

      renderToDocument(foo)
      `window.console.warn = window.org_warn_console; window.console.error = window.org_error_console;`
      expect(`test_log`.first).to match /Instead the Hash \{\} was returned/
    end
    it "will generate a message if render returns a Component class" do
      stub_const 'Foo', Class.new(React::Component::Base)
      foo = Class.new(React::Component::Base)
      foo.class_eval do
        def render; Foo; end
      end

      renderToDocument(foo)
      `window.console.warn = window.org_warn_console; window.console.error = window.org_error_console;`
      expect(`test_log`.first).to match /Did you mean Foo()/
    end
    it "will generate a message if more than 1 element is generated" do
      foo = Class.new(React::Component::Base)
      foo.class_eval do
        def render; "hello".span; "goodby".span; end
      end

      renderToDocument(foo)
      `window.console.warn = window.org_warn_console; window.console.error = window.org_error_console;`
      expect(`test_log`.first).to match /Instead 2 elements were generated/
    end
    it "will generate a message if the element generated is not the element returned" do
      foo = Class.new(React::Component::Base)
      foo.class_eval do
        def render; "hello".span; "goodby".span.delete; end
      end

      renderToDocument(foo)
      `window.console.warn = window.org_warn_console; window.console.error = window.org_error_console;`
      expect(`test_log`.first).to match /A different element was returned than was generated within the DSL/
    end
  end

  describe 'Event handling' do
    before do
      stub_const 'Foo', Class.new
      Foo.class_eval do
        include React::Component
      end
    end

    it 'works in render method' do
      Foo.class_eval do
        define_state(:clicked) { false }

        def render
          React.create_element('div').on(:click) do
            mutate.clicked true
          end
        end
      end

      element = React.create_element(Foo)
      instance = React::Test::Utils.render_into_document(element)
      React::Test::Utils.simulate(:click, instance)
      expect(instance.state.clicked).to eq(true)
    end

    it 'invokes handler on `this.props` using emit' do
      Foo.class_eval do
        param :_onFooSubmit, type: Proc
        after_mount :setup

        def setup
          puts "***************************** about to emit******************************"
          self.emit(:foo_submit, 'bar')
          puts "***************************** emitted!!! ********************************"
        rescue Exception => e
          puts "FAILED FAILED FAILED #{e}"
        end

        def render
          React.create_element('div')
        end
      end

      expect { |b|
        element = React.create_element(Foo).on(:foo_submit, &b)
        React::Test::Utils.render_into_document(element)
      }.to yield_with_args('bar')
    end

    it 'invokes handler with multiple params using emit' do
      Foo.class_eval do
        param :_onFooInvoked, type: Proc
        after_mount :setup

        def setup
          self.emit(:foo_invoked, [1,2,3], 'bar')
        end

        def render
          React.create_element('div')
        end
      end

      expect { |b|
        element = React.create_element(Foo).on(:foo_invoked, &b)
        React::Test::Utils.render_into_document(element)
      }.to yield_with_args([1,2,3], 'bar')
    end
  end

  describe '#refs' do
    before do
      stub_const 'Foo', Class.new
      Foo.class_eval do
        include React::Component
      end
    end

    it 'correctly assigns refs' do
      Foo.class_eval do
        def render
          React.create_element('input', type: :text, ref: :field)
        end
      end

      instance = renderToDocument(Foo)
      expect(instance.refs[:field]).not_to be_nil
    end

    it 'accesses refs through `refs` method' do
      Foo.class_eval do
        def render
          React.create_element('input', type: :text, ref: :field).on(:click) do
            refs[:field].value = 'some_stuff'
          end
        end
      end

      instance = React::Test::Utils.render_into_document(React.create_element(Foo))
      React::Test::Utils.simulate(:click, instance)
      expect(instance.refs[:field].value).to eq('some_stuff')
    end

    it "allows access the actual DOM node", v13_exclude: true do
      Foo.class_eval do
        after_mount do
          dom = refs[:my_div].to_n
          `dom.innerHTML = 'Modified'`
        end

        def render
          React.create_element('div', ref: :my_div) { "Original Content" }
        end
      end

      instance = renderToDocument(Foo)
      expect(`#{instance.dom_node}.innerHTML`).to eq('Modified')
    end
  end

  describe '#render' do
    it 'supports element building helpers' do
      stub_const 'Foo', Class.new
      Foo.class_eval do
        include React::Component

        def render
          div do
            span { params[:foo] }
          end
        end
      end

      stub_const 'Bar', Class.new
      Bar.class_eval do
        include React::Component
        def render
          div do
            present Foo, foo: 'astring'
          end
        end
      end

      expect(Bar).to render_static_html('<div><div><span>astring</span></div></div>')
    end

    it 'builds single node in top-level render without providing a block' do
      stub_const 'Foo', Class.new
      Foo.class_eval do
        include React::Component

        def render
          div
        end
      end

      expect(Foo).to render_static_html('<div></div>')
    end

    it 'redefines `p` to make method missing work' do
      stub_const 'Foo', Class.new
      Foo.class_eval do
        include React::Component

        def render
          div {
            p(class_name: 'foo')
            p
            div { 'lorem ipsum' }
            p(id: '10')
          }
        end
      end

      markup = '<div><p class="foo"></p><p></p><div>lorem ipsum</div><p id="10"></p></div>'
      expect(Foo).to render_static_html(markup)
    end

    it 'only overrides `p` in render context' do
      stub_const 'Foo', Class.new
      Foo.class_eval do
        include React::Component

        before_mount do
          p 'first'
        end

        after_mount do
          p 'second'
        end

        def render
          div
        end
      end

      expect(Kernel).to receive(:p).with('first')
      expect(Kernel).to receive(:p).with('second')
      renderToDocument(Foo)
    end
  end

  describe 'isMounted()' do
    it 'returns true if after mounted' do
      stub_const 'Foo', Class.new
      Foo.class_eval do
        include React::Component

        def render
          React.create_element('div')
        end
      end

      component = renderToDocument(Foo)
      expect(component.mounted?).to eq(true)
    end
  end

  describe '.params_changed?' do

    before(:each) do
      stub_const 'Foo', Class.new(React::Component::Base)
      Foo.define_method :needs_update? do |next_params, next_state|
        next_params.changed?
      end
      @foo = Foo.new(nil)
    end

    it "returns false if new and old params are the same" do
      @foo.instance_variable_set("@native", `{props: {value1: 1, value2: 2}}`)
      expect(@foo.should_component_update?(`{value2: 2, value1: 1}`, `null`)).to be_falsy
    end

    it "returns true if new and old params are have different values" do
      @foo.instance_variable_set("@native", `{props: {value1: 1, value2: 2}}`)
      expect(@foo.should_component_update?(`{value2: 2, value1: 2}`, `null`)).to be_truthy
    end

    it "returns true if new and old params are have different keys" do
      @foo.instance_variable_set("@native", `{props: {value1: 1, value2: 2}}`)
      expect(@foo.should_component_update?(`{value2: 2, value1: 1, value3: 3}`, `null`)).to be_truthy
    end
  end

  describe '#state_changed?' do

    empties = [`{}`, `undefined`, `null`, `false`]

    before(:each) do
      stub_const 'Foo', Class.new(React::Component::Base)
      Foo.define_method :needs_update? do |next_params, next_state|
        next_state.changed?
      end
      @foo = Foo.new(nil)
    end

    it "returns false if both new and old states are empty" do
      empties.each do |empty1|
        empties.each do |empty2|
          @foo.instance_variable_set("@native", `{state: #{empty1}}`)
          expect(@foo.should_component_update?(`{}`, empty2)).to be_falsy
        end
      end
    end

    it "returns true if old state is empty, but new state is not" do
      empties.each do |empty|
        @foo.instance_variable_set("@native", `{state: #{empty}}`)
        expect(@foo.should_component_update?(`{}`, `{foo: 12}`)).to be_truthy
      end
    end

    it "returns true if new state is empty, but old state is not" do
      empties.each do |empty|
        @foo.instance_variable_set("@native", `{state: {foo: 12}}`)
        expect(@foo.should_component_update?(`{}`, empty)).to be_truthy
      end
    end

    it "returns true if new state and old state have different time stamps" do
      @foo.instance_variable_set("@native", `{state: {'***_state_updated_at-***': 12}}`)
      expect(@foo.should_component_update?(`{}`, `{'***_state_updated_at-***': 13}`)).to be_truthy
    end

    it "returns false if new state and old state have the same time stamps" do
      @foo.instance_variable_set("@native", `{state: {'***_state_updated_at-***': 12}}`)
      expect(@foo.should_component_update?(`{}`, `{'***_state_updated_at-***': 12}`)).to be_falsy
    end

  end

  describe '#children' do
    before(:each) do
      stub_const 'Foo', Class.new
      Foo.class_eval do
        include React::Component
        def render
          React.create_element('div') { 'lorem' }
        end
      end
    end

    it 'returns React::Children collection with child elements' do
      ele = React.create_element(Foo) {
        [React.create_element('a'), React.create_element('li')]
      }
      instance = React::Test::Utils.render_into_document(ele)

      children = instance.children

      expect(children).to be_a(React::Children)
      expect(children.count).to eq(2)
      expect(children.map(&:element_type)).to eq(['a', 'li'])
    end

    it 'returns an empty Enumerator if there are no children' do
      ele = React.create_element(Foo)
      instance = React::Test::Utils.render_into_document(ele)
      nodes = instance.children.each
      expect(nodes.size).to eq(0)
      expect(nodes.count).to eq(0)
    end
  end
end
end
