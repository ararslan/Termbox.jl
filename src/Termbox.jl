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

immutable TermboxException <: Exception
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

type CellAttribute
    attrs::UInt16

    function CellAttribute(; color::Symbol=:default, options::Vector{Symbol}=Symbol[])
        attrs = if color == :default
            0x00
        elseif color == :black
            0x01
        elseif color == :red
            0x02
        elseif color == :green
            0x03
        elseif color == :yellow
            0x04
        elseif color == :blue
            0x05
        elseif color == :magenta
            0x06
        elseif color == :cyan
            0x07
        elseif color == :white
            0x08
        else
            throw(ArgumentError("unrecognized color '$color'"))
        end
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

type Cell
    char::Char
    foreground::CellAttribute
    background::CellAttribute
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
`CellAttribute`s.
"""
function set_clear_attributes!{T<:CellAttribute}(fg::T, bg::T)
    return ccall((:tb_set_clear_attributes, libtermbox), Void,
                 (UInt16, UInt16), fg.attrs, bg.attrs)
end

"""
    Termbox.sync!()

Synchronize the internal back buffer with the terminal.
"""
function synchronize!()
    return ccall((:tb_present, libtermbox), Void, ())
end

"""
    Termbox.setcursor!(x, y)

Set the cursor's position to `(x, y)`. `(0, 0)` corresponds to the character in the upper
left corner of the terminal window. Both coordinates must be nonnegative integers.
"""
function setcursor!(x::Int32, y::Int32)
    (x >= 0 && y >= 0) || throw(ArgumentError(""))
    return ccall((:tb_set_cursor, libtermbox), Void, (Cint, Cint), x, y)
end

setcursor!{T<:Signed}(x::T, y::T) = setcursor(Int32(x), Int32(y))

"""
    Termbox.hidecursor!()

Hide the cursor. Note that the cursor is hidden by default.
"""
function hidecursor!()
    return ccall((:tb_set_cursor, libtermbox), Void, (Cint, Cint), Int32(-1), Int32(-1))
end


### Module initialization

function __init__()
    rc = ccall((:tb_init, libtermbox), Cint, ())
    rc < 0 && throw(TermboxException(rc))
    atexit() do
        ccall((:tb_shutdown, libtermbox), Void, ())
    end
end

end # module
