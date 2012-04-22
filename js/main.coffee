# Set of color channels, I put alpha first
# because it seems most important
class Color
    constructor: (@a, @r, @g, @b) ->

    to_string: ->
        out = "rgba(#{Math.floor(@r*256)},#{Math.floor(@g*256)},#{Math.floor(@b*256)},#{@a})"
        return out

# Takes a list of Color objects and
# returns a new Color with is the average.
mix_colors = (colors) ->
    total_a = 0
    for color in colors
        total_a += color.a
    if total_a == 0
        return new Color(0, 0, 0, 0)

    out_channels = {}
    for channel in ['r', 'g', 'b']
        this_total = 0
        for color in colors
            this_total += (color[channel] * color.a)
        average = this_total / total_a
        out_channels[channel] = average

    average_a = total_a / colors.length
    return new Color(average_a, out_channels.r, out_channels.g, out_channels.b)

class EvolveEffect
    constructor: ->
    get_color: ->
    step: (ms, area) ->


class DirectionalEffect
    constructor: ->
        @mode = "resting"
        @amount = 0
        @direction = 0.2

    step: (ms, area) ->
        next_effect = @make_successor()
        next_effect.mode = @mode
        next_effect.amount = @amount
        next_effect.direction = @direction

        if @mode is "resting"
            next_effect.amount = @get_ancestor(area).amount
            if @get_elder_sibling(area).mode is "planning"
                next_effect.mode = "planning"
        if @mode is "planning"
            if (@get_elder_sibling(area).mode isnt "resting" and @get_younger_sibling(area).mode isnt "resting")
                next_effect.mode = "broadcasting"
        if @mode is "broadcasting"
            next_effect.amount = @amount + @direction
            #console.log "Example amount:", next_effect.amount, @direction
            if next_effect.amount >= 1
                next_effect.direction *= -1
            if next_effect.amount <= 0
                next_effect.amount = 0
                next_effect.direction *= -1
                next_effect.mode = "resting"
        return next_effect

    get_color: ->
        if @is_on
            return @get_active_color()
        else
            return new Color(0, 0, 0, 0)


class FluEffect extends DirectionalEffect
    constructor: ->
        super()
        @direction = 0.19

    get_ancestor: (area) ->
        area.w.effects.flu

    get_elder_sibling: (area) ->
        area.s.effects.flu

    get_younger_sibling: (area) ->
        area.n.effects.flu

    make_successor: ->
        return new FluEffect()

    get_color: ->
        if @mode is "planning"
            return new Color(0.3, 0, 1, 0)
        if @mode is "broadcasting"
            return new Color(0.6, 0, 1, 0)
        if @amount > 0
            return new Color(@amount, 0, 1, 0)
        else
            return new Color(@amount, 1, 0, 0)


class HopeEffect extends DirectionalEffect
    constructor: ->
        super()
        @direction = 0.27

    get_ancestor: (area) ->
        area.n.effects.hope

    get_elder_sibling: (area) ->
        area.w.effects.hope

    get_younger_sibling: (area) ->
        area.e.effects.hope

    make_successor: ->
        return new HopeEffect()

    get_color: ->
        if @mode is "planning"
            return new Color(0.3, 0, 0, 1)
        if @mode is "broadcasting"
            return new Color(0.6, 0, 0, 1)
        if @amount > 0
            return new Color(@amount, 0, 0, 1)
        else
            return new Color(@amount, 1, 1, 1)

    on_click: ->
        @amount = 0
        @direction = 0.27
        @mode = "resting"



# Given a pair of coordinates and a doubly-
# nested list of cells forming the field matrix,
# represent that cells neighbors as cardinal directions
class CellArea
    constructor: (row_num, col_num, rows) ->
        mod_wrap = (l, r) ->
            out = l % r
            if out < 0
                out = out + r
            return out

        #convenience vaiables to make indexing simpler
        num_rows = rows.length
        up = mod_wrap((row_num - 1), num_rows)
        down = mod_wrap((row_num + 1), num_rows)
        level = row_num

        num_columns = rows[0].length
        left = mod_wrap((col_num - 1), num_columns)
        right = mod_wrap((col_num + 1), num_columns)
        middle = col_num

        @n = rows[up][middle]
        @ne = rows[up][right]
        @e = rows[level][right]
        @se = rows[down][right]
        @s = rows[down][middle]
        @sw = rows[down][left]
        @w = rows[level][left]
        @nw = rows[up][left]


# A cell is a single square on the Field.
# It know about:
#   - its own unique set of Effects objects
#   - its own CellArea object
# Currently this class mixes in view logic.
# Therefore, the Cell must also know its
# coordinates and size on the canvas.
class Cell
    constructor: (@x, @y, @width, @height) ->
        @x = Math.round(@x)
        @y = Math.round(@y)
        @width = Math.round(@width)
        @height = Math.round(@height)
        @effects = {
            flu: new FluEffect()
            hope: new HopeEffect()
        }
        #these must be set before step() and draw() are called
        @next_effects = null
        @area = null
        

    # examine the Area and calculate what the next
    # set of effects will be (but don't switch to them yet)
    step: (ms) ->
        @next_effects = {}
        for name, effect of @effects
            @next_effects[name] = effect.step(ms, @area)

    # Switch over to the next set of effects, which should
    # have already been computed using step()
    flip: ->
        @effects = @next_effects
        @next_effects = null

    # Draw a square to the 2d context (ctx).
    # The color is averaged from the current set of Effects.
    draw: (ctx) ->
        colors = []
        for name, effect of @effects
            colors.push(effect.get_color())
        mixed = mix_colors(colors)
        ctx.fillStyle = mixed.to_string()
        ctx.fillRect(@x, @y, @width, @height)

    # Notify all of the effects that this cell has been
    # clicked, if they care.
    on_click: ->
        for name, effect of @effects
            if effect.on_click?
                effect.on_click()


# A 2d array of cells, as well as the coordinates and size
# used to draw each of the cells and the timing state
# used to increment the cell state logic
class Field
    constructor: (@x, @y, @width, @height, num_rows, num_columns) ->
        @x = Math.round(@x)
        @y = Math.round(@y)
        @width = Math.round(@width)
        @height = Math.round(@height)
        row_height = @height / num_rows
        column_width = @width / num_columns
        @last_time = Math.floor(new Date().getTime())

        @rows = []
        for row_num in [0...num_rows]
            this_row = []
            for col_num in [0...num_columns]
                this_x = @x + (col_num * column_width)
                this_y = @y + (row_num * row_height)
                this_row.push(new Cell(this_x, this_y, column_width, row_height))
            @rows.push this_row

        # Now that all cells exist, introduce them to each other
        # with CellArea objects
        for row_num in [0...num_rows]
            for col_num in [0...num_rows]
                this_cell = @rows[row_num][col_num]
                this_cell_area = new CellArea(row_num, col_num, @rows)
                this_cell.area = this_cell_area
        @rows[0][0].effects.flu.mode = "planning"
        @rows[5][5].effects.hope.mode = "planning"

    draw: (ctx) ->
        for row in @rows
            for cell in row
                cell.draw(ctx)
        return

    # adjust the click coordinates for the Field's offset
    # and notify the cell that was clicked.
    on_click: (x, y) ->
        field_x = x + @x
        field_y = y + @y

        row_height = @height / @rows.length
        column_width = @width / @rows[0].length

        row_num = Math.floor(field_y / row_height)
        column_num = Math.floor(field_x / column_width)
        @rows[row_num][column_num].on_click()

    # Given the current time (ms), tell
    # every cell to increment its state
    # zero to many times
    step: (ms) ->
        for each_ms in [@last_time..ms]
            #only notify every X ms
            if each_ms % 100 isnt 0
                continue
            # measure potential effects
            for row in @rows
                for cell in row
                    cell.step(each_ms)
            # implement effects
            for row in @rows
                for cell in row
                    cell.flip()
        @last_time = ms

class Billboard
    constructor: (@x, @y, @width, @height) ->

    draw: (ctx) ->
        ctx.clearRect(@x, @y, @width, @height)


# Use the reqestAnimationFrame function appropriate to the browser
requestAnimationFrame = window.requestAnimationFrame || window.mozRequestAnimationFrame ||
                        window.webkitRequestAnimationFrame || window.msRequestAnimationFrame

# call .draw() on every object in the drawable_world list,
# passing in the context (ctx). Recursively repeat
# as close to 60Hz as possible.
draw_loop = (ctx, drawable_world) ->
    this_time = Math.floor(new Date().getTime())
    for drawable_item in drawable_world
        if drawable_item.step?
            drawable_item.step(this_time)

    for drawable_item in drawable_world
        if drawable_item.draw?
            drawable_item.draw(ctx)

    requestAnimationFrame( ->
        draw_loop(ctx, drawable_world)
    )



# Take an onclick event and a canvas,
# and return an {x, y} object with the
# mouse coordinates adjusted to place the 
# origin on the canvas instead of in the window
mouse_coordinates = (event, canvas) ->
    total_offset_x = 0
    total_offset_y = 0
    canvas_x = 0
    canvas_y = 0
    current_element = canvas

    while current_element isnt null
        total_offset_x += current_element.offsetLeft
        total_offset_y += current_element.offsetTop
        current_element = current_element.offsetParent

    ret = {}
    ret.x = event.pageX - total_offset_x
    ret.y = event.pageY - total_offset_y

    return ret

register_click_events = (canvas, field) ->
    $('canvas').click( (event) ->
        coordinates = mouse_coordinates(event, canvas)
        field.on_click(coordinates.x, coordinates.y)
    )

$( ->
    canvas = document.getElementById("canvas")
    ctx = canvas.getContext("2d")

    drawable_world = []
    drawable_world.push(new Billboard(0, 0, canvas.width, canvas.height))
    field = new Field(0, 0, canvas.width, canvas.height, 50, 50)
    drawable_world.push(field)
    register_click_events(canvas, field)
    
    draw_loop(ctx, drawable_world)
)
