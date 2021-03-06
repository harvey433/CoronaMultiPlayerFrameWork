-- Wrap text
function wrap(str, limit, indent, indent1)
  indent = indent or ""
  indent1 = indent1 or indent
  limit = limit or 72
  local here = 1-#indent1
  return indent1..str:gsub("(%s+)()(%S+)()",
                          function(sp, st, word, fi)
                            if fi-here > limit then
                              here = st - #indent
                              return "\n"..indent..word
                            end
                          end)
end
 
function explode(div,str)
  if (div=='') then return false end
  local pos,arr = 0,{}
  -- for each divider found
  for st,sp in function() return string.find(str,div,pos,true) end do
    table.insert(arr,string.sub(str,pos,st-1)) -- Attach chars left of current divider
    pos = sp + 1 -- Jump past current divider
  end
  table.insert(arr,string.sub(str,pos)) -- Attach chars right of last divider
  return arr
end
 
 
function wrappedText(str, limit, size, font, color, indent, indent1)
        str = explode("\n", str)
        size = tonumber(size) or 12
        color = color or {255, 255, 255}
        font = font or "Helvetica"      
 
        --apply line breaks using the wrapping function
        local i = 1
        local strFinal = ""
    while i <= #str do
                strW = wrap(str[i], limit, indent, indent1)
                strFinal = strFinal.."\n"..strW
                i = i + 1
        end
        str = strFinal
        
        --search for each line that ends with a line break and add to an array
        local pos, arr = 0, {}
        for st,sp in function() return string.find(str,"\n",pos,true) end do
                table.insert(arr,string.sub(str,pos,st-1)) 
                pos = sp + 1 
        end
        table.insert(arr,string.sub(str,pos)) 
                        
        --iterate through the array and add each item as a display object to the group
        local g = display.newGroup()
        local i = 1
    while i <= #arr do
                local t = display.newText( arr[i], 0, 0, font, size )    
                t:setTextColor( color[1], color[2], color[3] )
                t.x = math.floor(t.width/2)
                t.y = (size*1.3)*(i-1)
                g:insert(t)
                i = i + 1
        end
        return g
end