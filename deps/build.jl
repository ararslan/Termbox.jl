using BinDeps

BinDeps.@setup

vers = v"1.1.0"

libtermbox = library_dependency("libtermbox", aliases=["libtermbox.1"])

if isdir(srcdir(libtermbox))
    rm(srcdir(libtermbox), recursive=true)
    mkdir(srcdir(libtermbox))
    mkdir(joinpath(srcdir(libtermbox), "libtermbox-$vers"))
end

if isdir(BinDeps.downloadsdir(libtermbox))
    rm(BinDeps.downloadsdir(libtermbox), recursive=true)
    mkdir(BinDeps.downloadsdir(libtermbox))
end

provides(Sources, URI("https://github.com/nsf/termbox/archive/v$vers.tar.gz"), libtermbox,
         unpacked_dir="termbox-$vers")

provides(BuildProcess, (@build_steps begin
    GetSources(libtermbox)
    @build_steps begin
        ChangeDirectory(joinpath(srcdir(libtermbox), "termbox-$vers"))
        FileRule(joinpath(libdir(libtermbox), "libtermbox." * BinDeps.shlib_ext), @build_steps begin
            CreateDirectory(libdir(libtermbox))
            `./waf configure --prefix=`
            `./waf --targets=termbox_shared`
            `./waf install --targets=termbox_shared --destdir=$(BinDeps.usrdir(libtermbox))`
        end)
    end
end), libtermbox)

BinDeps.@install Dict(:libtermbox => :libtermbox)
