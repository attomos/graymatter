module GM
  module Parallax

    # Moves views relative to the `contentOffset` of a scroll view. You can move
    # the views faster or slower than the other elements to create a parallax
    # effect, or you can link two scroll views, so that scrolling one also
    # scrolls the other.
    #
    # If you assign link two `UIScrollView`s, the `contentOffset` will be
    # adjusted, not its frame position.  If you really want to adjust its
    # position, put it in an empty `UIView` and adjust that.
    #
    # Rules
    # -----
    # You can use booleans, numbers, or your own arbitrary formula.
    #
    # Numeric => the rate at which scaling should occur vertically.
    # true => the view will scroll with the view, useful to have views that are
    #   outside the scroll view move with scrolling in one direction or another
    # false => "fixes" the object, so that it stays in place during scrolling.
    # Array => [x_rate, y_rate] => the rate at which scaling should occur in
    #   both directions
    # Hash => {x: x_rate, y:y_rate} => same as Array, but more explicit
    # CGPoint => used as an offset.  only useful when using a lambda, below
    # ->(offset){ CGPoint.new(offset.x + 1, offset.y + 1) } => receives the
    #                          content offset and returns a new x, y offset
    # ->(offset){ nil } => do nothing
    #
    # Examples
    # --------
    #
    # @example
    #     # these are all view objects of some sort.  this example shows how to
    #     # configure them to respond to scroll movements:
    #     #
    #     #   button => should not move with the window
    #     #   bg_image => should scroll past 2x faster (parallax)
    #     #   diagonal => moves left-to-right, which has the appearance of moving diagonally
    #     #   moving_thing => moves from right to left, when the contentOffset is between 1000 and 1400
    #     #   another_scroller => the y offset is tracked, the left is not
    #     prepare_parallax(scroll_view,
    #       button   => false,
    #       bg_image => 2,
    #       diagonal => ->(offset) { [offset.x, 0] }
    #       moving_thing => ->(offset) { (1000..1500) === contentOffset.y ? [contentOffset.y - 1000, 0] : nil },
    #       another_scroller => [0, 1],  # contentOffset.y will be the same when scroll_view is changed
    #       )
    #     prepare_parallax(another_scroller,
    #       scroll_view: [0, 1]  # for now, you need to establish the scrolling
    #       # relationship on both scroll views
    #       )
    def prepare_parallax(scroll_view, view_rules)
      scroll_view.delegate = self

      @parallax_views ||= {}
      @parallax_views[scroll_view] ||= {}
      @parallax_views[scroll_view].merge!(view_rules)

      @parallax_view_origins ||= {}
      view_rules.each do |view, rule|
        @parallax_view_origins[view] = view.frame.origin
      end
    end

    ##|
    ##|  SCROLLING
    ##|
    def scrollViewDidScroll(scroll_view)
      content_offset = scroll_view.contentOffset

      @parallax_views[scroll_view].each do |view, rule|
        x_rule = nil
        y_rule = nil
        point = nil

        if rule.is_a?(Proc)
          rule = rule.call(content_offset)
        end

        case rule
        when true
          # the view will move at the same rate as the scroll view.  for views
          # inside the scroll_view, this does absolutely nothing, but views
          # outside the scroll_view will be adjusted
          if view.isDescendantOfView(scroll_view)
            x_rule = 0
            y_rule = 0
          else
            x_rule = 1
            y_rule = 1
          end
        when false
          # fixes the view, which means it only needs to be moved if it is a
          # child view of the scroll_view
          if view.isDescendantOfView(scroll_view)
            x_rule = -1
            y_rule = -1
          else
            x_rule = 0
            y_rule = 0
          end
        when Numeric
          x_rule = rule
          y_rule = rule
        when Array
          x_rule = rule[0]
          y_rule = rule[1]
        when Hash
          x_rule = rule[:x]
          y_rule = rule[:y]
        when CGPoint
          point = rule
        when nil
          # cool, do nothing
        else
          raise "Unknown rule #{rule.inspect} in GM::Parallax"
        end

        if view.is_a?(UIScrollView)
          offset = view.contentOffset
          if x_rule
            offset.x = content_offset.x * x_rule
          end
          if y_rule
            offset.y = content_offset.y * y_rule
          end
          view.contentOffset = offset
        else
          f = view.frame
          origin = @parallax_view_origins[view]

          if point
            f.origin = CGPoint.new(origin.x + point.x, origin.y + point.y)
          else
            if x_rule
              f.origin.x = origin.x - content_offset.x * x_rule
            end
            if y_rule
              f.origin.y = origin.y - content_offset.y * y_rule
            end
          end

          view.frame = f
        end
      end
    end

  end
end
