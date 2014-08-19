require 'csspool'

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
        extended_result(result.to_s)
      end

      private

      def calculate_selector(selector, name)
        class_prefix = calculate_class_prefix(name)
        doc = CSSPool.CSS("#{selector} {}")
        replace_class(doc, class_prefix)
        doc_to_selector(doc)
      end

      def calculate_class_prefix(name)
        names = name.split('/')
        names = names[0...(names.index { |x| x.start_with?('_') } || -1)]
        return '' if names.empty?
        "#{names.join('__')}___"
      end

      def replace_class(doc, prefix)
        doc.rule_sets[0].selectors.map do |selector|
          selector.simple_selectors.each do |simple_selector|
            simple_selector.additional_selectors.each do |additional_selector|
              case additional_selector
              when CSSPool::Selectors::Class
                additional_selector.name = "#{prefix}#{additional_selector.name}"
              when CSSPool::Selectors::PseudoClass
                d = CSSPool.CSS("#{additional_selector.extra} {}")
                replace_class(d, prefix)
                additional_selector.extra = doc_to_selector(d)
              end
            end
          end
        end
      end

      def doc_to_selector(doc)
        doc.to_css.split("\n")[0][0...-1].strip.gsub('\00002e', '.')
      end

      def extended_result(result)
        result.split('/*').map { |x|
          next x if x.strip.empty?
          a, b = x.split("\n", 2)
          m = a.match(/\/app\/assets\/stylesheets\/([^. ]+)\./)
          next "#{a}\n#{b}" unless m
          selector = calculate_selector(b.split("\n")[0].strip[0...-1].strip, m[1])
          "#{a}\n#{selector} {\n#{b.split("\n", 2)[1]}"
        }.join('/*')
      end
    end
  end
end
