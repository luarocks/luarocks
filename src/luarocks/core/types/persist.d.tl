local record persist
    type PersistableTable = { string | number : string | number | boolean | PersistableTable }
end
return persist