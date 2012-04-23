# RGB Cells
# main.coffee
# Greg Sabo
#
# A Field is a 2d-array of Cells.
# A Cell is a Neighborhood, some Effects, and a Billboard.
# A Neighborhood is a set of references to 8 nearby Cells.
# An Effect is protected state which generates a Color
#       for each frame depending on the state of the other
#       Effects in the surrounding Neighborhood.
# A Billboard is a rectangle that is repeatedly drawn on an HTML canvas
#       in a certain Color.
# A Color is some amount of alpha, red, green, and blue.
#
# This program initializes a Field of Cells then repeatedly
# calculates the changes in Effects to each of those Cells,
# displaying the resulting Colors on Billboards using an HTML canvas.

window.onload = ->
    canvas = document.getElementById("canvas")
    ctx = canvas.getContext("2d")

    drawable_world = []
    field = new Field(0, 0, canvas.width, canvas.height, 50, 50)
    drawable_world.push(field)
    register_click_events(canvas, field)
    
    draw_loop(ctx, drawable_world)


requestAnimationFrame = (window.requestAnimationFrame ||
                        window.mozRequestAnimationFrame ||
                        window.webkitRequestAnimationFrame ||
                        window.msRequestAnimationFrame)


draw_loop = (ctx, drawable_world) ->
    for drawable_item in drawable_world
        drawable_item.draw(ctx)

    requestAnimationFrame( ->
        draw_loop(ctx, drawable_world)
    )


# a drawable 2d array of cells
class Field
    constructor: (@x, @y, @width, @height, num_rows, num_columns) ->
        row_height = @height / num_rows
        column_width = @width / num_columns

        @rows = []
        for row_num in [0...num_rows]
            this_row = []
            for col_num in [0...num_columns]
                this_x = @x + (col_num * column_width)
                this_y = @y + (row_num * row_height)
                cell_billboard = new Billboard(this_x, this_y,
                    column_width, row_height)
                this_row.push(new Cell(cell_billboard))
            @rows.push(this_row)

        # Now that all cells exist, introduce them to each other
        # with Neighborhood objects
        for row_num in [0...num_rows]
            for col_num in [0...num_rows]
                this_cell = @rows[row_num][col_num]
                this_cell.neighborhood = new Neighborhood(row_num, col_num, @rows)

    draw: (ctx) ->
        for row in @rows
            for cell in row
                cell.step()

        for row in @rows
            for cell in row
                cell.draw(ctx)

    on_click: (x, y) ->
        field_x = x + @x
        field_y = y + @y

        row_height = @height / @rows.length
        column_width = @width / @rows[0].length

        row_num = Math.floor(field_y / row_height)
        column_num = Math.floor(field_x / column_width)
        @rows[row_num][column_num].on_click()


class Cell
    constructor: (@billboard) ->
        effects_list = [
            new ConwayEffect(new Color(1, 1, 0, 0)),
            new ConwayEffect(new Color(1, 0, 1, 0)),
            new ConwayEffect(new Color(1, 0, 0, 1)),
            new ConwayEffect(new Color(1, 0.5, 0.5, 0)),
            new ConwayEffect(new Color(1, 0.5, 0, 0.5)),
            new ConwayEffect(new Color(1, 0, 0.5, 0.5))
        ]
        @effects = {}
        for effect in effects_list
            @effects[effect.get_key()] = effect

        @next_effects = null
        # We don't know the neighborhood at construction time
        @neighborhood = null
        

    # Determine next set of effects, but don't switch yet
    step: ->
        @next_effects = {}
        for name, effect of @effects
            @next_effects[name] = effect.make_next(@neighborhood)

    # Switch over to the next set of effects.
    flip: ->
        @effects = @next_effects
        @next_effects = null

    # A cell can draw itself, but it must refer to its Effects
    # to determine its color.
    draw: (ctx) ->
        @flip()
        colors = []
        for name, effect of @effects
            colors.push(effect.get_color())
        mixed = mix_colors(colors)
        @billboard.set_color(mixed)
        @billboard.draw(ctx)

    on_click: ->
        for name, effect of @effects
            if effect.on_click?
                effect.on_click()


class Neighborhood
    #rows is a doubly-nested list of Cells
    constructor: (row_num, column_num, rows) ->
        donut_rows = new DonutArray(rows)

        @neighbor_list = []
        for row_offset in [-1, 0, 1]
            for column_offset in [-1, 0, 1]
                if row_offset == column_offset == 0
                    continue
                neighbor = donut_rows.get(
                    row_num + row_offset,
                    column_num + column_offset)
                @neighbor_list.push(neighbor)

class DonutArray
    constructor: (@rows) ->

    get: (row_num, column_num) ->
        wrapped_row_num = @mod_wrap(row_num, @rows.length)
        wrapped_column_num = @mod_wrap(column_num, @rows[0].length)
        return @rows[wrapped_row_num][wrapped_column_num]

    # Python-like modulo
    mod_wrap: (lhs, rhs) ->
        out = lhs % rhs
        if out < 0
            out = out + rhs
        return out


class ConwayEffect
    constructor: (@on_color) ->
        @is_alive = Math.random() > 0.5

    make_next: (neighborhood) ->
        num_live_neighbors = 0
        for neighbor_cell in neighborhood.neighbor_list
            neighbor_conway = neighbor_cell.effects[@get_key()]
            if neighbor_conway.is_alive
                num_live_neighbors += 1

        next_conway = new ConwayEffect(@on_color)
        next_conway.is_alive = @will_be_alive(num_live_neighbors, @is_alive)
        return next_conway
    
    will_be_alive: (num_live_neighbors, was_alive) ->
        if num_live_neighbors < 2
            return no
        else if num_live_neighbors > 3
            return no
        else if num_live_neighbors is 3
            return yes
        else
            return was_alive

    get_key: ->
        return @on_color.to_string()
    
    get_color: ->
        if @is_alive
            return @on_color
        else
            return null


class Color
    constructor: (@a, @r, @g, @b) ->
        @cached_string = null

    to_string: ->
        if @cached_string?
            return @cached_string

        as_list = ['rgba(',
            Math.floor(@r*256), ',',
            Math.floor(@g*256), ',',
            Math.floor(@b*256), ',',
            @a, ')']
        as_string = as_list.join('')
        @cached_string = as_string
        return as_string


# average a list of colors, ignore nulls
mix_colors = (colors) ->
    present_colors = []
    for color in colors
        if color isnt null
            present_colors.push(color)
    colors = present_colors

    total_a = 0
    for color in colors
        total_a += color.a
    if total_a == 0
        return new Color(1, 0, 0, 0)

    out_channels = {}
    for channel in ['r', 'g', 'b']
        this_total = 0
        for color in colors
            this_total += (color[channel] * color.a)
        average = this_total / total_a
        out_channels[channel] = average

    average_a = total_a / colors.length
    return new Color(average_a, out_channels.r, out_channels.g, out_channels.b)


# An immovable, color-changing rectangle
class Billboard
    constructor: (x, y, width, height) ->
        # canvas performs better with integer coordinates
        @x = Math.round(x)
        @y = Math.round(y)
        @width = Math.round(width)
        @height = Math.round(height)

        @color_string = null
        @is_dirty = yes

    set_color: (new_color) ->
        new_color_string = new_color.to_string()
        if new_color_string != @color_string
            @is_dirty = yes
            @color_string = new_color_string

    draw: (ctx) ->
        # only redraws if color changes
        # this assumes the canvas is not being cleared each frame
        # and that nothing ever obstructs the square
        if @is_dirty
            ctx.fillStyle = @color_string
            ctx.fillRect(@x, @y, @width, @height)
        @is_dirty = no


# adjust coordinates to canvas space
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
    canvas = document.getElementById('canvas')
    canvas.onclick = (event) ->
        coordinates = mouse_coordinates(event, canvas)
        field.on_click(coordinates.x, coordinates.y)

