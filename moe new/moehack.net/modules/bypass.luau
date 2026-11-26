do 
    --if setstackhidden then
    --    setstackhidden(getgenv().getfenv, true)
    --end


    if moehack.data.game_name == "Universal" or moehack.data.game_name == "Flick" then
        do -- Adonis Anti Cheat Bypass (not mine)
            local g = getinfo or debug.getinfo
            local d = false
            local h = {}

            local x, y

            setthreadidentity(2)

            for i, v in getgc(true) do
                if typeof(v) == "table" then
                    local a = rawget(v, "Detected")
                    local b = rawget(v, "Kill")
                
                    if typeof(a) == "function" and not x then
                        x = a
                        
                        local o; o = hookfunction(x, function(c, f, n)
                            if c ~= "_" then
                            end
                            
                            return true
                        end)

                        table.insert(h, x)
                    end

                    if rawget(v, "Variables") and rawget(v, "Process") and typeof(b) == "function" and not y then
                        y = b
                        local o; o = hookfunction(y, function(f)
                        end)

                        table.insert(h, y)
                    end
                end
            end
            local o; o = hookfunction(getrenv().debug.info, newcclosure(function(...)
                local a, f = ...

                if x and a == x then
                    return coroutine.yield(coroutine.running())
                end
                
                return o(...)
            end))
            setthreadidentity(7)
        end
    end

end

if moehack.data.game_name == "Operation One" then -- not my shit bro
    local oldStrByte; oldStrByte = hookfunction(string.byte, newcclosure(function(a0, a1)
        if (checkcaller() or type(a0) ~= 'string' or not (a0:sub(1, 1) == '{' and a0:sub(-1) == '}')) then return oldStrByte(a0, a1) end;

        const luraph = getstack(3, 1);
        luraph[1] = luraph[2];
        luraph[5] = #luraph[2];
        setstack(3, 4, luraph[5]);

        return oldStrByte(luraph[1], a1);
    end));
end