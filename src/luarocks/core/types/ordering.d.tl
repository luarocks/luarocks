local record ordering
    record Ordering<K>
       is {K}
       sub_orders: {K: Ordering<K>}
    end
 
    type SortBy<K> = table.SortFunction<K> | Ordering<K>
 end

 return ordering