local record version
    record Version
       is {number}
       string: string
       revision: number
       metamethod __eq: function(Version, Version): boolean
       metamethod __lt: function(Version, Version): boolean
       metamethod __le: function(Version, Version): boolean
    end
 
    record Constraint
       op: string
       version: Version | string
       no_upgrade: boolean
    end
 end
 
 return version