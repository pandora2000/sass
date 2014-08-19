module Sass
  module Tree
    # A static node that is the root node of the Sass document.
    class RootNode < Node
      # The Sass template from which this node was created
      #
      # @param template [String]
      attr_reader :template

      # @param template [String] The Sass template from which this node was created
      def initialize(template)
        super()
        @template = template
      end

      # Runs the dynamic Sass code *and* computes the CSS for the tree.
      # @see #to_s
      def render
        Visitors::CheckNesting.visit(self)
        result = Visitors::Perform.visit(self)
        Visitors::CheckNesting.visit(result) # Check again to validate mixins
        result, extends = Visitors::Cssize.visit(result)
        Visitors::Extend.visit(result, extends)
        #extended_result(result.to_s)
        result.to_s
      end

      private

      def extended_result(result)
        File.open('/tmp/hoge', 'w') do |f|
          f.puts result.split('/*').map { |x|
            a, b = x.split("\n", 2)
            m = a.match(/\/app\/assets\/stylesheets\/([^. \/]+)\./)
            next nil unless m
            [m[1], b.split("\n")[0].strip[0...-1]]
          }.compact.to_s
        end
        result
      end
    end
  end
end
