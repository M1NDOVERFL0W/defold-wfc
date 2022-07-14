
require("libwfc.xmlsimple")
local xdocument = newParser()
local model = require("libwfc.model")

local tiledmodel = {
    patterns            = {},
    colors              = {},
}

OverlappingModel = {}

OverlappingModel.new = function( name, N, width, height, periodicInput, periodic, symmetry, ground, heuristic )

    local tmodel = model_new( width, height, N, periodic, heuristic )
    tmodel.colors   = {}
    tmodel.patterns = {}
    tmodel.type     = "OverlappingModel"

    pprint(name)
    
    local bitmapId    = libwfc.image_load('samples/'..name..'.png')
    local w, h, comp, data = libwfc.image_get(bitmapId)
    local bitmap     = { Width = w, Height = h, Comp = comp, data = data }
    local SX, SY    = bitmap.Width, bitmap.Height
    local sample    = {}
    
    for y = 0, SY-1 do 
        for x = 0, SX - 1 do 
            local color = GetPixel(bitmap, x, y)

            local i = 0
            for k,c in pairs(tmodel.colors) do 
                if( c.r == color.r and c.b == color.b and c.g == color.g ) then break end 
                i = i + 1
            end

            if( i == table.count(tmodel.colors) ) then table.insert( tmodel.colors, color ) end
            sample[x + y * SX] = i;
        end 
    end
    
    local C = table.count(tmodel.colors)
    local W = ToPower( C, tmodel.N * tmodel.N )

    function pattern( func )
        local result = {}
        for y=0, tmodel.N-1 do
            for x = 0, tmodel.N-1 do 
                result[x + y * tmodel.N] = func(x,y)
            end 
        end
        return result
    end

    function patternFromSample( x, y ) 
        return pattern( function( dx, dy ) return sample[ (x+dx) % SX  + ((y + dy) % SY) * SX] end )
    end
    function rotate( p ) 
        return pattern( function(x,y) return p[tmodel.N - 1 -y + x * tmodel.N] end) 
    end
    function reflect( p ) 
        return pattern( function(x,y) return p[tmodel.N - 1 - x + y * tmodel.N] end) 
    end

    function index( p )
        local result = 0
        local power = 1 
        for i = 0, table.count(p) - 1 do 
            result = result + p[table.count(p) - 1 - i] * power 
            power = power * C 
        end
        return result
    end

    function patternFromIndex( ind )
        local residue = ind 
        local power =  W 
        local result = {}
        for i=0, tmodel.N * tmodel.N-1 do 
            power = power / C 
            local count = 0 
            while( residue >= power) do 
                residue = residue - power 
                count = count + 1
            end
            result[i] = count       
        end
        return result
    end

    local Tweights = {} 
    local ordering = {} 
    local ycount = SY - tmodel.N + 1
    if(periodicInput) then ycount = SY end 
    local xcount = SX - tmodel.N + 1
    if(periodicInput) then xcount = SX end 
    for y = 0, ycount - 1 do 
        for x = 0, xcount - 1 do

            local ps = { [0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {}, [5] = {}, [6] = {}, [7] = {} } 
            ps[0]   = patternFromSample(x, y)
            ps[1]   = reflect(ps[0])
            ps[2]   = rotate(ps[0])
            ps[3]   = reflect(ps[2])
            ps[4]   = rotate(ps[2])
            ps[5]   = reflect(ps[4])
            ps[6]   = rotate(ps[4])
            ps[7]   = reflect(ps[6])

            for k = 0, symmetry-1 do 
                local ind = index(ps[k])
                if(Tweights[ind]) then 
                    Tweights[ind] = Tweights[ind] + 1
                else 
                    Tweights[ind] = 1
                    table.insert(ordering, ind) 
                end 
            end 
        end
    end 

    tmodel.T = table.count(Tweights)
    tmodel.ground = ground 
    tmodel.patterns = {} 
    tmodel.weights = {} 

    local counter = 0 
    for k,w in ipairs(ordering) do 
        tmodel.patterns[counter] = patternFromIndex(w) 
        tmodel.weights[counter + 1] = Tweights[w]
        counter = counter + 1
    end

    function agrees( p1, p2, dx, dy )

        local xmin = math.max(dx, 0)
        local xmax = tmodel.N
        if(dx < 0) then xmax = dx + tmodel.N end
        local ymin = math.max(dy, 0)
        local ymax = tmodel.N
        if(dy < 0) then ymax = dy + tmodel.N end
        for y = ymin, ymax-1 do 
            for x = xmin, xmax - 1 do 
                if (p1[x + tmodel.N * y] ~= p2[x - dx + tmodel.N * (y - dy)]) then return false end
            end 
        end 
        return true
    end

    tmodel.propagator = {} 
    for d = 0, 3 do 
        tmodel.propagator[d] = {}
        for t = 0, tmodel.T-1 do 
            local list = {} 
            for t2 = 0, tmodel.T-1 do 
                if( agrees( tmodel.patterns[t], tmodel.patterns[t2], dx[d+1], dy[d+1]) == true ) then 
                    table.insert(list, t2) 
                end
            end
            tmodel.propagator[d][t] = {} 
            for c = 0, table.count(list)-1 do 
                tmodel.propagator[d][t][c] = list[c+1] 
            end 
        end 
    end 

    tmodel.GraphicsSave = function( self, filename )
        local bdata, w, h, comp = OverlappingModel.Graphics(self) 
        --Write out data to filename 
        local count = libwfc.image_save( filename, w, h, bdata)
        assert(count == w * h, "[ IMAGE ERROR ] "..count.."  "..(w*h))
    end

    return tmodel
end

-- Draw the data to a png bitmap
OverlappingModel.Graphics = function( tmodel )

    local bitmapData = {}

    if (tmodel.observed[0] >= 0) then 
        for y = 0, tmodel.MY-1 do 
        
            local dy = tmodel.N - 1
            if y < tmodel.MY - tmodel.N + 1 then dy = 0 end 
            for x = 0, tmodel.MX-1 do
                local dx = tmodel.N - 1
                if x < tmodel.MX -tmodel.N + 1 then dx = 0 end 
                local c = tmodel.colors[tmodel.patterns[tmodel.observed[x - dx + (y - dy) *tmodel.MX]][dx + dy *tmodel. N] + 1]
                bitmapData[x + y * tmodel.MX] = makeColor( c.r, c.g, c.b )
            end
        end
    else
    
        for i = 0, table.count(tmodel.wave) - 1 do
            local contributors, r, g, b = 0, 0, 0, 0
            local x = i % tmodel.MX
            local y = math.floor( i / tmodel.MX )

            for dy = 0, tmodel.N-1 do 
                for dx = 0, tmodel.N-1 do
                    local sx = x - dx
                    if (sx < 0) then sx = sx + tmodel.MX end

                    sy = y - dy
                    if (sy < 0) then sy = sy + tmodel.MY end

                    local s = sx + sy * tmodel.MX
                    if (tmodel.periodic == false and ((sx + tmodel.N > tmodel.MX) or (sy + tmodel.N > tmodel.MY) or (sx < 0 or sy < 0)) ) then 
                        local q = 1
                    else
                        for t = 0, tmodel.T -1 do
                            if (tmodel.wave[s][t]) then                        
                                contributors = contributors + 1;
                                local color = tmodel.colors[ tmodel.patterns[t][dx + dy * tmodel.N] + 1 ]
                                r = r + color.r
                                g = g + color.g
                                b = b + color.b
                            end
                        end
                    end
                end
            end
            bitmapData[i] = makeColor( r/contributors, g/contributors, b/contributors )
        end
    end

    return bitmapData, tmodel.MX, tmodel.MY, 4
end

return OverlappingModel