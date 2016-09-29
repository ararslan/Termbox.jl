using BinDeps

BinDeps.@setup

libtermbox = library_dependency("libtermbox", aliases=["libtermbox.1"])

if isdir(srcdir(libtermbox))
    rm(srcdir(libtermbox), recursive=true)
    mkdir(srcdir(libtermbox))
end

if isdir(downloadsdir(libtermbox))
    rm(downloadsdir(libtermbox), recursive=true)
    mkdir(downloadsdir(libtermbox))
end

vers = v"1.1.0"

provides(Sources, URI("https://github.com/nsf/termbox/archive/v$vers.tar.gz"), libtermbox,
         unpacked_dir="libtermbox-$vers")

provides(BuildProcess, (@build_steps begin
    GetSources(libtermbox)
    @build_steps begin
        ChangeDirectory(joinpath(srcdir(libtermbox), "libtermbox-$vers"))
        FileRule(joinpath(libdir(libtermbox), "libtermbox." * BinDeps.shlib_ext), @build_steps begin
            CreateDirectory(libdir(libtermbox))
            `./waf configure --prefix=`
            `./waf --targets=termbox_shared`
            `./waf install --targets=termbox_shared --destdir=$(usrdir(libtermbox))`
        end)
    end
end), libtermbox)

BinDeps.@install Dict(:libtermbox => :libtermbox)
