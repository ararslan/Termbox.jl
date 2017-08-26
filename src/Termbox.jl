__precompile__()

module Termbox

const _deps = normpath(dirname(@__FILE__), "..", "deps", "deps.jl")

if isfile(_deps)
    include(_deps)
else
    error("Termbox.jl is not properly installed. Please run `Pkg.build(\"Termbox\")` ",
          "and restart Julia.")
end


### Types and exceptions

struct TermboxException <: Exception
    code::Integer
    msg::String

    function TermboxException(code::Integer)
        msg = if code == -1
            "Unsupported terminal"
        elseif code == -2
            "Failed to open TTY"
        elseif code == -3
            "Pipe trap error"
        else
            "Unknown error"
        end
        new(code, msg)
    end
end

Base.showerror(io::IO, ex::TermboxException) =
    Base.print(io, "Unable to initialize Termbox: ", ex.msg, ", code ", ex.code)

mutable struct CellAttributes
    attrs::UInt16

    function CellAttributes(; color::Symbol=:default, options::Vector{Symbol}=Symbol[])
        attrs = color == :default ? 0x00 :
                color == :black   ? 0x01 :
                color == :red     ? 0x02 :
                color == :green   ? 0x03 :
                color == :yellow  ? 0x04 :
                color == :blue    ? 0x05 :
                color == :magenta ? 0x06 :
                color == :cyan    ? 0x07 :
                color == :white   ? 0x08 :
                throw(ArgumentError("unrecognized color '$color'"))
        for opt in options
            if opt == :bold
                attrs |= 0x0100
            elseif opt == :underline
                attrs |= 0x0200
            elseif opt == :reverse
                attrs |= 0x0400
            else
                throw(ArgumentError("unrecognized option '$opt'"))
            end
        end
        return new(attrs)
    end
end

mutable struct Cell
    char::UInt32
    foreground::UInt16
    background::UInt16

    function Cell(c::Char;
                  fgcolor::Symbol=:default,
                  fgoptions::Vector{Symbol}=Symbol[],
                  bgcolor::Symbol=:default,
                  bgoptions::Vector{Symbol}=Symbol[])
        fg = CellAttributes(color=fgcolor, options=fgoptions).attrs
        bg = CellAttributes(color=bgcolor, options=bgoptions).attrs
        return new(UInt32(c), fg, bg)
    end

    function Cell(c::Char;
                  foreground::T=T(color=:default),
                  background::T=T(color=:default)) where T<:CellAttributes
        return new(UInt32(c), foreground.attrs, background.attrs)
    end
end

mutable struct Event
    event::UInt8
    modifier::UInt8
    key::UInt16
    char::UInt32
    w::Int32
    h::Int32
    x::Int32
    y::Int32
end


### State-querying functions

"""
    Termbox.width() -> Int32

Return the width of the terminal back buffer, i.e. the terminal window's width in
characters.
"""
function width()
    return ccall((:tb_width, libtermbox), Cint, ())
end

"""
    Termbox.height() -> Int32

Return the height of the terminal back buffer, i.e. the terminal window's height in
characters.
"""
function height()
    return ccall((:tb_height, libtermbox), Cint, ())
end


### State-setting functions

"""
    Termbox.init!()

Initialize Termbox. Termbox *must* be manually shut down using `shutdown!`.
"""
function init!()
    rc = ccall((:tb_init, libtermbox), Cint, ())
    rc < 0 && throw(TermboxException(rc))
    return
end

"""
    Termbox.shutdown!()

Shut down Termbox.
"""
function shutdown!()
    return ccall((:tb_shutdown, libtermbox), Void, ())
end

"""
    Termbox.clear!()

Clear the internal back buffer and reset to the default or declared clear attributes.
See `set_clear_attributes`.
"""
function clear!()
    return ccall((:tb_clear, libtermbox), Void, ())
end

"""
    Termbox.set_clear_attributes!(foreground, background)

Set the cell attributes to be applied when `clear!()` is called. Both fields must be
`CellAttributes`s.
"""
function set_clear_attributes!(fg::T, bg::T) where T<:CellAttributes
    return ccall((:tb_set_clear_attributes, libtermbox), Void,
                 (UInt16, UInt16), fg.attrs, bg.attrs)
end

"""
    Termbox.sync!()

Synchronize the internal back buffer with the terminal.
"""
function sync!()
    return ccall((:tb_present, libtermbox), Void, ())
end

"""
    Termbox.setcursor!(x, y)

Set the cursor's position to `(x, y)`. `(0, 0)` corresponds to the character in the upper
left corner of the terminal window. Both coordinates must be nonnegative integers.
"""
function setcursor!(x::T, y::T) where T<:Signed
    (x >= 0 && y >= 0) || throw(ArgumentError("cursor coordinates must be nonnegative"))
    return ccall((:tb_set_cursor, libtermbox), Void, (Cint, Cint), Int32(x), Int32(y))
end

"""
    Termbox.hidecursor!()

Hide the cursor. Note that the cursor is hidden by default.
"""
function hidecursor!()
    return ccall((:tb_set_cursor, libtermbox), Void, (Cint, Cint), Int32(-1), Int32(-1))
end

"""
    Termbox.changecell!(x, y, char, foreground, background)

Modify the cell at `(x, y)` to contain `char` with the given `foreground` and
`background`, passed as `CellAttributes`.
"""
function changecell!(x::S, y::S, char::Char, fg::T, bg::T) where {S<:Signed, T<:CellAttributes}
    return ccall((:tb_change_cell, libtermbox), Void,
                 (Cint, Cint, UInt32, UInt16, UInt16),
                 Int32(x), Int32(y), UInt32(char), fg.attrs, bg.attrs)
end

"""
    Termbox.putcell!(x, y, cell)

Modify the cell at `(x, y)` to contain the `Cell` object `cell`.
"""
function putcell!(x::T, y::T, cell::Cell) where T<:Signed
    return changecell!(Int32(x), Int32(y), cell.char, cell.foreground, cell.background)
end

# TODO: Improve the documentation of this:
"""
    Termbox.setinputmode!(mode) -> Int32

Set the input mode.
"""
function setinputmode!(mode::Symbol)
    m = mode == :current ? 0 :
        mode == :escape  ? 1 :
        mode == :alt     ? 2 :
        mode == :mouse   ? 4 :
        throw(ArgumentError("unrecognized input mode '$mode'"))
    return ccall((:tb_set_input_mode, libtermbox), Cint, (Cint,), m)
end


### Module initialization

function __init__()
    init!()
    atexit() do
        shutdown!()
    end
end

end # module
