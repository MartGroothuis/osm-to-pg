local srid = 4326 -- WGS84 (Latitude/Longitude), ideaal voor geografische analyse

local tables = {}

-- 1. Specifieke tabel voor Highway Analyse (Lijngeometrieën)
tables.highways = osm2pgsql.define_way_table('highways', {
    { column = 'osm_id', type = 'bigint' },
    { column = 'highway', type = 'text', not_null = true },
    { column = 'name', type = 'text' },
    { column = 'layer', type = 'integer' },
    { column = 'maxspeed', type = 'text' },
    { column = 'oneway', type = 'text' },
    { column = 'surface', type = 'text' },
    { column = 'tags', type = 'jsonb' }, -- Overige tags voor diepere analyse
    { column = 'geom', type = 'linestring', projection = srid, not_null = true }
})

-- 2. Generieke tabel voor Punten (POI's, Knooppunten, etc.)
tables.osm_nodes = osm2pgsql.define_node_table('osm_nodes', {
    { column = 'layer', type = 'integer' },
    { column = 'tags', type = 'jsonb' },
    { column = 'geom', type = 'point', projection = srid, not_null = true }
})

-- 3. Generieke tabel voor Vlakken/Polygons (Gebouwen, Gebieden, Grenzen)
tables.osm_areas = osm2pgsql.define_area_table('osm_areas', {
    { column = 'layer', type = 'integer' },
    { column = 'tags', type = 'jsonb' },
    { column = 'geom', type = 'geometry', projection = srid, not_null = true }
})

-- Ongewenste import/mapper tags die we strippen om geheugen en schijfruimte te besparen
local delete_keys = {
    'attribution', 'comment', 'created_by', 'fixme', 'note', 'note:*', 'odbl',
    'source', 'source:*', 'source_ref', 'CLC:*', 'geobase:*', 'canvec:*',
    'tiger:*', 'gnis:*', 'NHD:*', 'nhd:*', 'ref:ruian:*', 'ref:ruian',
    'import', 'import_uuid', 'SK53_bulk:load'
}

local clean_tags = osm2pgsql.make_clean_tags_func(delete_keys)

-- Helpertabel voor versnelde checks op area-tags
local area_tags = {
    building = true, landuse = true, amenity = true, leisure = true,
    natural = true, boundary = true, water = true, wetland = true
}

local function has_area_tags(tags)
    if tags.area == 'yes' then return true end
    if tags.area == 'no' then return false end
    for k in pairs(tags) do
        if area_tags[k] then return true end
    end
    return false
end

-- ============================================================================
-- VERWERKING
-- ============================================================================

function osm2pgsql.process_node(object)
    if clean_tags(object.tags) then return end

    tables.osm_nodes:insert({
        layer = (object.tags.layer and tonumber(object.tags.layer)) or nil,
        tags = (function()
            local t = {}
            for k,v in pairs(object.tags) do t[k]=v end
            t.layer = nil
            return t
        end)(),
        geom = object:as_point()
    })
end

function osm2pgsql.process_way(object)
    if clean_tags(object.tags) then return end

    -- A. Highway verwerking (Geoptimaliseerd voor netwerkanalyse)
    -- Include closed ways that are NOT area-like so closed highways (rings) are preserved
    -- as lines; only treat closed ways as areas when they have explicit area tags.
    if object.tags.highway and (not object.is_closed or not has_area_tags(object.tags)) then
        local highway_type = object.tags.highway
        
        -- Maak een kopie van tags en verwijder al expliciet opgeslagen kolommen
        local extra_tags = {}
        for k, v in pairs(object.tags) do extra_tags[k] = v end
        extra_tags.highway = nil
        extra_tags.name = nil
        extra_tags.maxspeed = nil
        extra_tags.oneway = nil
        extra_tags.surface = nil
        extra_tags.layer = nil

        local layer_val = nil
        if object.tags.layer then
            local n = tonumber(object.tags.layer)
            if n then layer_val = n end
        end

        tables.highways:insert({
            osm_id = object.id,
            highway = highway_type,
            name = object.tags.name,
            layer = layer_val,
            maxspeed = object.tags.maxspeed,
            oneway = object.tags.oneway,
            surface = object.tags.surface,
            tags = extra_tags,
            geom = object:as_linestring()
        })
        return
    end

    -- B. Generieke Polygon verwerking
    if object.is_closed and has_area_tags(object.tags) then
        local area_tags_copy = {}
        for k, v in pairs(object.tags) do area_tags_copy[k] = v end
        local layer_val = nil
        if area_tags_copy.layer then
            local n = tonumber(area_tags_copy.layer)
            if n then layer_val = n end
        end
        area_tags_copy.layer = nil

        tables.osm_areas:insert({
            layer = layer_val,
            tags = area_tags_copy,
            geom = object:as_polygon()
        })
    end
end

function osm2pgsql.process_relation(object)
    if clean_tags(object.tags) then return end

    local rel_type = object.tags.type

    -- Generieke Polygon verwerking voor Multipolygons & Boundaries
    if rel_type == 'multipolygon' or rel_type == 'boundary' then
        tables.osm_areas:insert({
            tags = object.tags,
            geom = object:as_multipolygon()
        })
    end
end
