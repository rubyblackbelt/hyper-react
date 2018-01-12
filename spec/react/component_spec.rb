require 'spec_helper'

describe 'React::Component', js: true do

  it 'defines component spec methods' do
    on_client do
      class Foo
        include React::Component
        def initialize(native = nil)
        end

        def render
          React.create_element('div')
        end
      end
    end
    # class methods
    expect_evaluate_ruby("Foo.respond_to?(:initial_state)").to be_truthy
    expect_evaluate_ruby("Foo.respond_to?(:default_props)").to be_truthy
    expect_evaluate_ruby("Foo.respond_to?(:prop_types)").to be_truthy
    # instance_methods
    expect_evaluate_ruby("Foo.new.respond_to?(:component_will_mount)").to be_truthy
    expect_evaluate_ruby("Foo.new.respond_to?(:component_did_mount)").to be_truthy
    expect_evaluate_ruby("Foo.new.respond_to?(:component_will_receive_props)").to be_truthy
    expect_evaluate_ruby("Foo.new.respond_to?(:should_component_update?)").to be_truthy
    expect_evaluate_ruby("Foo.new.respond_to?(:component_will_update)").to be_truthy
    expect_evaluate_ruby("Foo.new.respond_to?(:component_did_update)").to be_truthy
    expect_evaluate_ruby("Foo.new.respond_to?(:component_will_unmount)").to be_truthy
  end

  describe 'Life Cycle' do
    before(:each) do
      on_client do
        class Foo
          include React::Component
          def self.call_history
            @call_history ||= []
          end
          def render
            React.create_element('div') { 'lorem' }
          end
        end
      end
    end

    it 'invokes `before_mount` registered methods when `componentWillMount()`' do
      mount 'Foo' do
        Foo.class_eval do
          before_mount :bar, :bar2
          def bar; self.class.call_history << "bar"; end
          def bar2; self.class.call_history << "bar2"; end
        end
      end
      expect_evaluate_ruby("Foo.call_history").to eq(["bar", "bar2"])
    end

    it 'invokes `after_mount` registered methods when `componentDidMount()`' do
      mount 'Foo' do
        Foo.class_eval do
          after_mount :bar3, :bar4
          def bar3; self.class.call_history << "bar3"; end
          def bar4; self.class.call_history << "bar4"; end
        end
      end
      expect_evaluate_ruby("Foo.call_history").to eq(["bar3", "bar4"])
    end

    it 'allows multiple class declared life cycle hooker' do
      evaluate_ruby do
        Foo.class_eval do
          before_mount :bar
          def bar; self.class.call_history << "bar"; end
        end

        class FooBar
          include React::Component
          after_mount :bar2
          def self.call_history
            @call_history ||= []
          end
          def bar2; self.class.call_history << "bar2"; end
          def render
            React.create_element('div') { 'lorem' }
          end
        end
        instance = React::Test::Utils.render_component_into_document(Foo)
        instance = React::Test::Utils.render_component_into_document(FooBar)
      end
      expect_evaluate_ruby("Foo.call_history").to eq(["bar"])
      expect_evaluate_ruby("FooBar.call_history").to eq(["bar2"])
    end

    it 'allows block for life cycle callback' do
      expect_evaluate_ruby do
        Foo.class_eval do
          before_mount do
            set_state({ foo: "bar" })
          end
        end
        instance = React::Test::Utils.render_component_into_document(Foo)
        instance.state[:foo]
      end.to eq('bar')
    end
  end

  describe 'New style setter & getter' do
    before(:each) do
      on_client do
        class Foo
          include React::Component
          def render
            div { state.foo }
          end
        end
      end
    end

    it 'implicitly will create a state variable when first written' do
      mount 'Foo' do
        Foo.class_eval do
          before_mount do
            state.foo! 'bar'
          end
        end
      end
      # this was a 'have_xpath' check, but these are totally unreliable in capybara with webdrivers
      # leading to false positives and negatives
      # this simple check for string inclusion makes this checks reliable
      expect(page.body[-35..-19]).to include("<div>bar</div>")
    end

    it 'allows kernal method names like "format" to be used as state variable names' do
      mount 'Foo' do
        Foo.class_eval do
          before_mount do
            state.format! 'yes'
            state.foo! state.format
          end
        end
      end
      expect(page.body[-35..-19]).to include("<div>yes</div>")
    end

    it 'returns an observer with the bang method and no arguments' do
      mount 'Foo' do
        Foo.class_eval do
          before_mount do
            state.foo!(state.baz!.class.name)
          end
        end
      end
      expect(page.body[-50..-19]).to include("<div>React::Observable</div>")
    end

    it 'returns the current value of a state when written' do
      mount 'Foo' do
        Foo.class_eval do
          before_mount do
            state.baz! 'bar'
            state.foo!(state.baz!('pow'))
          end
        end
      end
      expect(page.body[-35..-19]).to include("<div>bar</div>")
    end

    it 'can access an explicitly defined state`' do
      mount 'Foo' do
        Foo.class_eval do
          define_state foo: :bar
        end
      end
      expect(page.body[-35..-19]).to include("<div>bar</div>")
    end
  end

  describe 'State setter & getter' do
    before(:each) do
      on_client do
        class Foo
          include React::Component
          def render
            React.create_element('div') { 'lorem' }
          end
        end
      end
    end

    it 'defines setter using `define_state`' do
      expect_evaluate_ruby do
        Foo.class_eval do
          define_state :foo
          before_mount :set_up
          def set_up
            mutate.foo 'bar'
          end
        end
        instance = React::Test::Utils.render_component_into_document(Foo)
        instance.state.foo
      end.to eq('bar')
    end

    it 'defines init state by passing a block to `define_state`' do
      expect_evaluate_ruby do
        element_to_render = React.create_element(Foo)
        Foo.class_eval do
          define_state(:foo) { 10 }
        end
        dom_el = JS.call(:eval, "document.body.appendChild(document.createElement('div'))")
        instance = React.render(element_to_render, dom_el)
        instance.state.foo
      end.to eq(10)
    end

    it 'defines getter using `define_state`' do
      expect_evaluate_ruby do
        Foo.class_eval do
          define_state(:foo) { 10 }
          before_mount :bump
          def bump
            mutate.foo(state.foo + 20)
          end
        end
        instance = React::Test::Utils.render_component_into_document(Foo)
        instance.state.foo
      end.to eq(30)
    end

    it 'defines multiple state accessors by passing array to `define_state`' do
      expect_evaluate_ruby do
        Foo.class_eval do
          define_state :foo, :foo2
          before_mount :set_up
          def set_up
            mutate.foo 10
            mutate.foo2 20
          end
        end
        instance = React::Test::Utils.render_component_into_document(Foo)
        [ instance.state.foo, instance.state.foo2 ]
      end.to eq([10, 20])
    end

    it 'invokes `define_state` multiple times to define states' do
      expect_evaluate_ruby do
        Foo.class_eval do
          define_state(:foo) { 30 }
          define_state(:foo2) { 40 }
        end
        instance = React::Test::Utils.render_component_into_document(Foo)
        [ instance.state.foo, instance.state.foo2 ]
      end.to eq([30, 40])
    end

    it 'can initialize multiple state variables with a block' do
      expect_evaluate_ruby do
        Foo.class_eval do
          define_state(:foo, :foo2) { 30 }
        end
        instance = React::Test::Utils.render_component_into_document(Foo)
        [ instance.state.foo, instance.state.foo2 ]
      end.to eq([30, 30])
    end

    it 'can mix multiple state variables with initializers and a block' do
      expect_evaluate_ruby do
        Foo.class_eval do
          define_state(:x, :y, foo: 1, bar: 2) {3}
        end
        instance = React::Test::Utils.render_component_into_document(Foo)
        [ instance.state.x, instance.state.y, instance.state.foo, instance.state.bar ]
      end.to eq([3, 3, 1, 2])
    end

    it 'gets state in render method' do
      mount 'Foo' do
        Foo.class_eval do
          define_state(:foo) { 10 }
          def render
            React.create_element('div') { state.foo }
          end
        end
      end
      expect(page.body[-35..-19]).to include("<div>10</div>")
    end

    it 'supports original `setState` as `set_state` method' do
      expect_evaluate_ruby do
        Foo.class_eval do
          before_mount do
            self.set_state(foo: 'bar')
          end
        end
        instance = React::Test::Utils.render_component_into_document(Foo)
        instance.state[:foo]
      end.to eq('bar')
    end

    it '`set_state!` method works and doesnt replace other state' do
      # this test changed because the function replaceState is gone in react
      expect_evaluate_ruby do
        Foo.class_eval do
          before_mount do
            set_state(foo: 'bar')
            set_state!(bar: 'lorem')
          end
        end
        instance = React::Test::Utils.render_component_into_document(Foo)
        [ instance.state[:foo], instance.state[:bar] ]
      end.to eq(['bar', 'lorem'])
    end

    it 'supports original `state` method' do
      mount 'Foo' do
        Foo.class_eval do
          before_mount do
            self.set_state(foo: 'bar')
          end

          def render
            div { self.state[:foo] }
          end
        end
      end
      expect(page.body[-35..-19]).to include("<div>bar</div>")
    end

    it 'transforms state getter to Ruby object' do
      mount 'Foo' do
        Foo.class_eval do
          define_state :foo

          before_mount do
            mutate.foo [{a: "Hello"}]
          end

          def render
            div { state.foo[0][:a] }
          end
        end
      end
      expect(page.body[-40..-19]).to include("<div>Hello</div>")
    end
  end

  describe 'Props' do
    describe 'this.props could be accessed through `params` method' do
      before do
        on_client do
          class Foo
            include React::Component
          end
        end
      end

      it 'reads from parent passed properties through `params`' do
        mount 'Foo', prop: 'foobar' do
          Foo.class_eval do
            def render
              React.create_element('div') { params[:prop] }
            end
          end
        end
        expect(page.body[-40..-19]).to include("<div>foobar</div>")
      end

      it 'accesses nested params as orignal Ruby object' do
        mount 'Foo', prop: [{foo: 10}] do
          Foo.class_eval do
            def render
              React.create_element('div') { params[:prop][0][:foo] }
            end
          end
        end
        expect(page.body[-35..-19]).to include("<div>10</div>")
      end
    end

    describe 'Props Updating', v13_only: true do
      before do
        on_client do
          class Foo
            include React::Component
          end
        end
      end

      it '`setProps` as method `set_props` is no longer supported' do
        expect_evaluate_ruby do
          Foo.class_eval do
            def render
              React.create_element('div') { params[:foo] }
            end
          end
          instance = React::Test::Utils.render_component_into_document(Foo, foo: 10)
          begin
            instance.set_props(foo: 20)
          rescue
            'got risen'
          end
        end.to eq('got risen')
      end

      it 'original `replaceProps` as method `set_props!` is no longer supported' do
        expect_evaluate_ruby do
          Foo.class_eval do
            def render
              React.create_element('div') { params[:foo] ? 'exist' : 'null' }
            end
          end
          instance = React::Test::Utils.render_component_into_document(Foo, foo: 10)
          begin
            instance.set_props!(bar: 20)
          rescue
            'got risen'
          end
        end.to eq('got risen')
      end
    end

    describe 'Prop validation' do
      before do
        on_client do
          class Foo
            include React::Component
          end
        end
      end

      it 'specifies validation rules using `params` class method' do
        expect_evaluate_ruby do
          Foo.class_eval do
            params do
              requires :foo, type: String
              optional :bar
            end
          end
          Foo.prop_types
        end.to have_key('_componentValidator')
      end

      xit 'logs error in warning if validation failed' do
        # TODO: seems like no logging is done in hyper-react, should maybe better raise instead
        evaluate_ruby do
          class Lorem; end
          Foo.class_eval do
            params do
              requires :foo
              requires :lorem, type: Lorem
              optional :bar, type: String
            end

            def render; div; end
          end
          React::Test::Utils.render_component_into_document(Foo, bar: 10, lorem: Lorem.new)
        end
        expect(page.driver.browser.manage.logs.get(:browser).map { |m| m.message.gsub(/\\n/, "\n") }.to_a.join("\n"))
          .to match(/Warning: Failed prop( type|Type): In component `Foo`\nRequired prop `foo` was not specified\nProvided prop `bar` could not be converted to String/)
      end

      xit 'should not log anything if validation pass' do
        # see above, it should neither log or raise?
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
        on_client do
          class Foo
            include React::Component
            params do
              optional :foo, default: 'foo'
              optional :bar, default: 'bar'
            end

            def render
              div { params[:foo] + '-' + params[:bar]}
            end
          end
        end
        mount 'Foo'
        expect(page.body[-40..-19]).to include("<div>foo-bar</div>")
        mount 'Foo', foo: 'lorem'
        expect(page.body[-40..-19]).to include("<div>lorem-bar</div>")
      end
    end
  end

  describe 'Anonymous Component' do
    xit "will not generate spurious warning messages" do
      # TODO, see above
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
    it "will generate a message if render returns something other than an Element or a String" do
      mount 'Foo' do
        class Foo < React::Component::Base
          def render; Hash.new; end
        end
      end
      expect(page.driver.browser.manage.logs.get(:browser).map { |m| m.message.gsub(/\\n/, "\n") }.to_a.join("\n"))
          .to match(/Instead the Hash \{\} was returned/)
    end
    it "will generate a message if render returns a Component class" do
      mount 'Foo' do
        class Foo < React::Component::Base
          def render; Foo; end
        end
      end
      expect(page.driver.browser.manage.logs.get(:browser).map { |m| m.message.gsub(/\\n/, "\n") }.to_a.join("\n"))
        .to match(/Did you mean Foo()/)
    end
    it "will generate a message if more than 1 element is generated" do
      mount 'Foo' do
        class Foo < React::Component::Base
          def render; "hello".span; "goodby".span; end
        end
      end
      expect(page.driver.browser.manage.logs.get(:browser).map { |m| m.message.gsub(/\\n/, "\n") }.to_a.join("\n"))
        .to match(/Instead 2 elements were generated/)
    end
    it "will generate a message if the element generated is not the element returned" do
      mount 'Foo' do
        class Foo < React::Component::Base
          def render; "hello".span; "goodby".span.delete; end
        end
      end
      expect(page.driver.browser.manage.logs.get(:browser).map { |m| m.message.gsub(/\\n/, "\n") }.to_a.join("\n"))
        .to match(/A different element was returned than was generated within the DSL/)
    end
  end

  describe 'Event handling' do
    before do
      on_client do
        class Foo
          include React::Component
        end
      end
    end

    it 'works in render method' do
      expect_evaluate_ruby do
        Foo.class_eval do
          define_state(:clicked) { false }

          def render
            React.create_element('div').on(:click) do
              mutate.clicked true
            end
          end
        end
        instance = React::Test::Utils.render_component_into_document(Foo)
        React::Test::Utils.simulate_click(instance)
        instance.state.clicked
      end.to eq(true)
    end

    it 'invokes handler on `this.props` using emit' do
      on_client do
        Foo.class_eval do
          param :_onFooSubmit, type: Proc
          after_mount :setup

          def setup
            self.emit(:foo_submit, 'bar')
          end

          def render
            React.create_element('div')
          end
        end
      end
      evaluate_ruby do
        element = React.create_element(Foo).on(:foo_submit) { 'bar' }
        React::Test::Utils.render_into_document(element)
      end
      expect(page.driver.browser.manage.logs.get(:browser).map { |m| m.message.gsub(/\\n/, "\n") }.to_a.join("\n"))
        .to_not match(/Exception raised/)
    end

    it 'invokes handler with multiple params using emit' do
      on_client do
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
      end

      evaluate_ruby do
        element = React.create_element(Foo).on(:foo_invoked) { return [1,2,3], 'bar' }
        React::Test::Utils.render_into_document(element)
      end
      expect(page.driver.browser.manage.logs.get(:browser).map { |m| m.message.gsub(/\\n/, "\n") }.to_a.join("\n"))
        .to_not match(/Exception raised/)
    end
  end

  describe '#refs' do
    before do
      on_client do
        class Foo
          include React::Component
        end
      end
    end

    xit 'correctly assigns refs' do
      on_client do
        Foo.class_eval do
          def render
            React.create_element('input', type: :text, ref: :field)
          end
        end
      end
      expect_evaluate_ruby do
        instance = React::Test::Utils.render_component_into_document(Foo)
        instance.refs[:field]
      end.not_to be_nil
      # TODO: original test asks for above not_to be_nil, but why should it not be nil?
      # ref: :field is no where set to anything else
      # not sure about this
    end

    it 'accesses refs through `refs` method' do
      on_client do
        Foo.class_eval do
          def render
            React.create_element('input', type: :text, ref: :field).on(:click) do
              refs[:field].value = 'some_stuff'
            end
          end
        end
      end
      expect_evaluate_ruby do
        instance = React::Test::Utils.render_component_into_document(Foo)
        React::Test::Utils.simulate_click(instance)
        instance.refs[:field].value
      end.to eq('some_stuff')
    end

    it "allows access the actual DOM node", v13_exclude: true do
      on_client do
        Foo.class_eval do
          after_mount do
            dom = refs[:my_div].to_n
            dom.JS['innerHTML'] = 'Modified'
          end

          def render
            React.create_element('div', ref: :my_div) { "Original Content" }
          end
        end
      end
      expect_evaluate_ruby do
        instance = React::Test::Utils.render_component_into_document(Foo)
        instance.dom_node.JS['innerHTML']
      end.to eq('Modified')
    end
  end

  describe '#render' do
    it 'supports element building helpers' do
      on_client do
        class Foo
          include React::Component

          def render
            div do
              span { params[:foo] }
            end
          end
        end

        class Bar
          include React::Component
          def render
            div do
              present Foo, foo: 'astring'
            end
          end
        end
      end
      evaluate_ruby do
        React::Test::Utils.render_component_into_document(Bar)
      end
      expect(page.body[-65..-19]).to include("<div><div><span>astring</span></div></div>")
    end

    it 'builds single node in top-level render without providing a block' do
      mount 'Foo' do
        class Foo
          include React::Component

          def render
            div
          end
        end
      end
      expect(page.body).to include('<div data-react-class="React.TopLevelRailsComponent" data-react-props="{&quot;render_params&quot;:{},&quot;component_name&quot;:&quot;Foo&quot;,&quot;controller&quot;:&quot;ReactTest&quot;}"><div></div></div>')
    end

    it 'redefines `p` to make method missing work' do
      mount 'Foo' do
        class Foo
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
      end
      expect(page.body).to include('<div><p class="foo"></p><p></p><div>lorem ipsum</div><p id="10"></p></div>')
    end

    xit 'only overrides `p` in render context' do
      # TODO dont know how to emulate the receives here
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

  describe 'new react 15/16 custom isMounted implementation' do
    it 'returns true if after mounted' do
      expect_evaluate_ruby do
        class Foo
          include React::Component

          def render
            React.create_element('div')
          end
        end

        component = React::Test::Utils.render_component_into_document(Foo)
        component.mounted?
      end.to eq(true)
    end
  end

  describe '.params_changed?' do

    before(:each) do
      on_client do
        class Foo < React::Component::Base
          def needs_update?(next_params, next_state)
            next_params.changed?
          end
        end
      end
    end

    it "returns false if new and old params are the same" do
      expect_evaluate_ruby do
        @foo = Foo.new(nil)
        @foo.instance_eval { @native.JS[:props] = JS.call(:eval, 'function bla(){return {value1: 1, value2: 2};}bla();') }
        @foo.should_component_update?({ value2: 2, value1: 1 }, {})
      end.to be_falsy
    end

    it "returns true if new and old params are have different values" do
      expect_evaluate_ruby do
        @foo = Foo.new(nil)
        @foo.instance_eval { @native.JS[:props] = JS.call(:eval, 'function bla(){return {value1: 1, value2: 2};}bla();') }
        @foo.should_component_update?({value2: 2, value1: 2}, {})
      end.to be_truthy
    end

    it "returns true if new and old params are have different keys" do
      expect_evaluate_ruby do
        @foo = Foo.new(nil)
        @foo.instance_eval { @native.JS[:props] = JS.call(:eval, 'function bla(){return {value1: 1, value2: 2};}bla();') }
        @foo.should_component_update?({value2: 2, value1: 1, value3: 3}, {})
      end.to be_truthy
    end
  end

  describe '#state_changed?' do

    before(:each) do
      on_client do
        class Foo < React::Component::Base
          def needs_update?(next_params, next_state)
            next_state.changed?
          end
        end

        EMPTIES = [`{}`, `undefined`, `null`, `false`]
      end
    end

    it "returns false if both new and old states are empty" do
      expect_evaluate_ruby do
        @foo = Foo.new(nil)
        return_values = []
        EMPTIES.each do |empty1|
          EMPTIES.each do |empty2|
            @foo.instance_eval { @native.JS[:state] = JS.call(:eval, "function bla(){return #{empty1};}bla();") }
            return_values << @foo.should_component_update?({}, Hash.new(empty2))
          end
        end
        return_values
      end.to all( be_falsy )
    end

    it "returns true if old state is empty, but new state is not" do
      expect_evaluate_ruby do
        @foo = Foo.new(nil)
        return_values = []
        EMPTIES.each do |empty|
          @foo.instance_eval { @native.JS[:state] = JS.call(:eval, "function bla(){return #{empty};}bla();") }
          return_values << @foo.should_component_update?({}, {foo: 12})
        end
        return_values
      end.to all( be_truthy )
    end

    it "returns true if new state is empty, but old state is not" do
      expect_evaluate_ruby do
        @foo = Foo.new(nil)
        return_values = []
        EMPTIES.each do |empty|
          @foo.instance_eval { @native.JS[:state] = JS.call(:eval, "function bla(){return {foo: 12};}bla();") }
          return_values << @foo.should_component_update?({}, Hash.new(empty))
        end
        return_values
      end.to all( be_truthy )
    end

    it "returns true if new state and old state have different time stamps" do
      expect_evaluate_ruby do
        @foo = Foo.new(nil)
        return_values = []
        EMPTIES.each do |empty|
          @foo.instance_eval { @native.JS[:state] = JS.call(:eval, "function bla(){return {'***_state_updated_at-***': 12};}bla();") }
          return_values << @foo.should_component_update?({}, {'***_state_updated_at-***' => 13})
        end
        return_values
      end.to all ( be_truthy )
    end

    it "returns false if new state and old state have the same time stamps" do
      expect_evaluate_ruby do
        @foo = Foo.new(nil)
        return_values = []
        EMPTIES.each do |empty|
          @foo.instance_eval { @native.JS[:state] = JS.call(:eval, "function bla(){return {'***_state_updated_at-***': 12};}bla();") }
          return_values << @foo.should_component_update?({}, {'***_state_updated_at-***' => 12})
        end
        return_values
      end.to all( be_falsy )
    end

  end

  describe '#children' do
    before(:each) do
      on_client do
        class Foo
          include React::Component
          def render
            React.create_element('div') { 'lorem' }
          end
        end
      end
    end

    it 'returns React::Children collection with child elements' do
      evaluate_ruby do
        ele = React.create_element(Foo) {
          [React.create_element('a'), React.create_element('li')]
        }
        instance = React::Test::Utils.render_into_document(ele)

        CHILDREN = instance.children
      end
      expect_evaluate_ruby("CHILDREN.class.name").to eq('React::Children')
      expect_evaluate_ruby("CHILDREN.count").to eq(2)
      expect_evaluate_ruby("CHILDREN.map(&:element_type)").to eq(['a', 'li'])
    end

    it 'returns an empty Enumerator if there are no children' do
      evaluate_ruby do
        ele = React.create_element(Foo)
        instance = React::Test::Utils.render_into_document(ele)
        NODES = instance.children.each
      end
      expect_evaluate_ruby("NODES.size").to eq(0)
      expect_evaluate_ruby("NODES.count").to eq(0)
    end
  end
end
