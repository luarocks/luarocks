local record rockmanifest
    record RockManifest
        type Entry = string | {string: Entry}
        entries: {string: Entry}
    end
end
return rockmanifest