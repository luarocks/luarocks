local record rockmanifest
    record RockManifest
        type Entry = string | {string: Entry}
        rock_manifest: {string: Entry}
    end
end
return rockmanifest