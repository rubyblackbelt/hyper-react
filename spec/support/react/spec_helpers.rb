if opal?
module React
  module SpecHelpers
    `var ReactTestUtils = React.addons.TestUtils`

    def renderToDocument(type, options = {})
      element = React.create_element(type, options)
      React::Test::Utils.render_into_document(element)
    end

    def build_element(type, options)
      component = React.create_element(type, options)
      element = `ReactTestUtils.renderIntoDocument(#{component.to_n})`
      `$(React.findDOMNode(element))`    # v0.13
    end

    def expect_component_to_eventually(component_class, opts = {}, &block)
      # Calls block after each update of a component until it returns true.
      # When it does set the expectation to true.  Uses the after_update
      # callback of the component_class, then instantiates an element of that
      # class The call back is only called on updates, so the call back is
      # manually called right after the element is created.  Because React.rb
      # runs the callback inside the components context, we have to setup a
      # lambda to get back to correct context before executing run_async.
      # Because run_async can only be run once it is protected by clearing
      # element once the test passes.
      element = nil
      check_block = lambda do
        context = block.arity > 0 ? self : element
        run_async do
          element = nil; expect(true).to be(true)
        end if element and context.instance_exec(element, &block)
      end
      component_class.after_update { check_block.call  }
      element = build_element component_class, opts
      check_block.call
    end
  end
end
end
