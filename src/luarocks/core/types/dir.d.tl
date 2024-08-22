local record dir
    record Dirs
        BINDIR: Dir
        INCDIR: Dir
        LIBDIR: Dir
    end
    record Dir
        subdir: string | {string}
        testfile: string
        pattern: {string}
        dir: string
        file: string
    end
end

return dir