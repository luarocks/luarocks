local record ordering
    record Ordering<K>
       {K}
       sub_orders: {K: Ordering<K>}
    end
 
    type SortBy<K> = table.SortFunction<K> | Ordering<K>
 end

 return ordering