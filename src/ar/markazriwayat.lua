-- {"id":100000,"ver":"1.0.0","libVer":"1.0.0","author":"RandomDude","repo":"https://github.com/user69hhhhh/Bruh-shosetsu-repos","dep":["url>=1.0.0","dkjson>=1.0.0"]}
--
-- Markaz Riwayat (markazriwayat.com) Shosetsu Extension
-- Arabic novel source extension for Shosetsu
--
-- API Endpoints:
--   * Library listing: /wp-json/theam/v1/library?page=N&per_page=24
--   * Search: /wp-json/theam/v1/library?page=N&per_page=24&s=QUERY
--   * Novel page: /novel/{slug}/
--   * Chapter page: /novel/{slug}/chapter-{N}/ OR /novel/{slug}/الفصل-{N}/
--
-- API Response Structure (confirmed from actual API call):
--   {
--     "page": 1,
--     "per_page": 24,
--     "total": 269,
--     "totalPages": 12,
--     "items": [
--       {
--         "id": 150589,
--         "title": "حكايات غريبة عن الأشباح",
--         "link": "https://markazriwayat.com/novel/strange-tales-of-the-ghosts/",
--         "cover": "https://markazriwayat.com/wp-content/uploads/2026/06/...",
--         "status": {"key": "on-going", "label": "مستمرة", "class": "is-ongoing"},
--         "chapters_count": 268,
--         "genres": [{"name": "تاريخي", "slug": "..."}],
--         "tags": [{"name": "رواية صينية", "slug": "..."}],
--         "summary_preview_html": "<p>**الوصف:**...</p>"
--       }
--     ]
--   }
--
-- HTML Selectors:
--   * Novel title: h1.manga-title
--   * Novel cover: .manga-cover-wrap img[data-src]
--   * Novel summary: #manga-summary
--   * Novel status: .status-pill.manga-status-pill
--   * Chapter list: .ch-list .ch-row
--   * Chapter title: .ch-title
--   * Chapter content: .reading-content

local baseURL = "https://markazriwayat.com"

--------------------------------------------------------------------------
-- JSON Decoder (Fallback for dkjson dependency)
--------------------------------------------------------------------------

local json = {}
do
    local function skipWhitespace(s, i)
        while i <= #s do
            local c = s:sub(i, i)
            if c ~= " " and c ~= "\t" and c ~= "\n" and c ~= "\r" then break end
            i = i + 1
        end
        return i
    end

    local parseValue

    local function parseString(s, i)
        i = i + 1
        local out = {}
        while true do
            local c = s:sub(i, i)
            if c == '"' then
                i = i + 1
                break
            elseif c == "\\" then
                local n = s:sub(i + 1, i + 1)
                if n == "n" then out[#out + 1] = "\n"
                elseif n == "t" then out[#out + 1] = "\t"
                elseif n == "r" then out[#out + 1] = "\r"
                elseif n == "u" then
                    local hex = s:sub(i + 2, i + 5)
                    local code = tonumber(hex, 16) or 63
                    if code < 128 then
                        out[#out + 1] = string.char(code)
                    elseif code < 2048 then
                        out[#out + 1] = string.char(192 + math.floor(code / 64), 128 + (code % 64))
                    else
                        out[#out + 1] = string.char(
                            224 + math.floor(code / 4096),
                            128 + (math.floor(code / 64) % 64),
                            128 + (code % 64)
                        )
                    end
                    i = i + 4
                else
                    out[#out + 1] = n
                end
                i = i + 2
            else
                out[#out + 1] = c
                i = i + 1
            end
        end
        return table.concat(out), i
    end

    local function parseNumber(s, i)
        local start = i
        while i <= #s and s:sub(i, i):match("[%d%.%-%+eE]") do
            i = i + 1
        end
        return tonumber(s:sub(start, i - 1)), i
    end

    local function parseArray(s, i)
        i = i + 1
        local arr = {}
        i = skipWhitespace(s, i)
        if s:sub(i, i) == "]" then return arr, i + 1 end
        while true do
            local v
            v, i = parseValue(s, i)
            arr[#arr + 1] = v
            i = skipWhitespace(s, i)
            local c = s:sub(i, i)
            if c == "," then
                i = skipWhitespace(s, i + 1)
            elseif c == "]" then
                i = i + 1
                break
            else
                break
            end
        end
        return arr, i
    end

    local function parseObject(s, i)
        i = i + 1
        local obj = {}
        i = skipWhitespace(s, i)
        if s:sub(i, i) == "}" then return obj, i + 1 end
        while true do
            i = skipWhitespace(s, i)
            local key
            key, i = parseString(s, i)
            i = skipWhitespace(s, i)
            i = i + 1
            i = skipWhitespace(s, i)
            local v
            v, i = parseValue(s, i)
            obj[key] = v
            i = skipWhitespace(s, i)
            local c = s:sub(i, i)
            if c == "," then
                i = skipWhitespace(s, i + 1)
            elseif c == "}" then
                i = i + 1
                break
            else
                break
            end
        end
        return obj, i
    end

    parseValue = function(s, i)
        i = skipWhitespace(s, i)
        local c = s:sub(i, i)
        if c == '"' then
            return parseString(s, i)
        elseif c == "{" then
            return parseObject(s, i)
        elseif c == "[" then
            return parseArray(s, i)
        elseif c == "t" and s:sub(i, i + 3) == "true" then
            return true, i + 4
        elseif c == "f" and s:sub(i, i + 4) == "false" then
            return false, i + 5
        elseif c == "n" and s:sub(i, i + 3) == "null" then
            return nil, i + 4
        else
            return parseNumber(s, i)
        end
    end

    function json.decode(s)
        if not s or s == "" then return nil end
        local ok, result = pcall(function()
            local v = parseValue(s, 1)
            return v
        end)
        if ok then return result end
        return nil
    end
end

--------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------

local function shrink(url)
    return url:gsub("^https?://[^/]+/", "")
end

local function mapStatus(key)
    if key == "on-going" then
        return NovelStatus(0)
    elseif key == "end" then
        return NovelStatus(1)
    elseif key == "canceled" then
        return NovelStatus(2)
    else
        return NovelStatus(2)
    end
end

local function summaryHtmlToText(html)
    if not html then return "" end
    local text = html
    text = text:gsub("<br%s*/?>", "\n")
    text = text:gsub("<[^>]->", "")
    text = text:gsub("&nbsp;", " ")
    text = text:gsub("&amp;", "&")
    text = text:gsub("&quot;", '"')
    text = text:gsub("&#039;", "'")
    text = text:gsub("<[^>]+>", "")
    return text:trim and text:trim() or text
end

local function novelFromApiItem(item)
    local cover = item.cover or ""
    local link = item.link and shrink(item.link) or ""
    return Novel {
        link = link,
        title = item.title or "",
        imageURL = cover,
    }
end

--------------------------------------------------------------------------
-- Extension Definition
--------------------------------------------------------------------------

return {
    id = 100000,
    name = "Markaz Riwayat",
    baseURL = baseURL,
    hasSearch = true,
    chapterType = ChapterType.HTML,
    imageURL = "https://markazriwayat.com/wp-content/uploads/2025/12/cropped-1000168054-192x192.jpg",

    listings = {
        Listing("All Novels", true, function(data)
            local page = data[PAGE] + 1
            local url = baseURL .. "/wp-json/theam/v1/library?page=" .. page .. "&per_page=24"
            local res = json.decode(HttpRequest.GET(url):text())
            local novels = {}
            if res and res.items then
                for _, item in ipairs(res.items) do
                    table.insert(novels, novelFromApiItem(item))
                end
            end
            return novels
        end),

        Listing("Ongoing", true, function(data)
            local page = data[PAGE] + 1
            local url = baseURL .. "/wp-json/theam/v1/library?page=" .. page .. "&per_page=24"
            local res = json.decode(HttpRequest.GET(url):text())
            local novels = {}
            if res and res.items then
                for _, item in ipairs(res.items) do
                    if item.status and item.status.key == "on-going" then
                        table.insert(novels, novelFromApiItem(item))
                    end
                end
            end
            return novels
        end),

        Listing("Completed", true, function(data)
            local page = data[PAGE] + 1
            local url = baseURL .. "/wp-json/theam/v1/library?page=" .. page .. "&per_page=24"
            local res = json.decode(HttpRequest.GET(url):text())
            local novels = {}
            if res and res.items then
                for _, item in ipairs(res.items) do
                    if item.status and item.status.key == "end" then
                        table.insert(novels, novelFromApiItem(item))
                    end
                end
            end
            return novels
        end),
    },

    parseNovel = function(novelURL, loadChapters)
        local url = baseURL .. "/" .. novelURL
        local html = HttpRequest.GET(url):text()
        local doc = Document(html)

        local titleEl = doc:selectFirst("h1.manga-title")
        local title = titleEl and titleEl:text():trim() or novelURL

        local imgEl = doc:selectFirst(".manga-cover-wrap img")
        local imageURL = ""
        if imgEl then
            imageURL = imgEl:attr("data-src")
            if not imageURL or imageURL == "" then
                imageURL = imgEl:attr("src")
            end
        end

        local summaryEl = doc:selectFirst("#manga-summary")
        local description = summaryEl and summaryHtmlToText(summaryEl:html()) or ""

        local status = NovelStatus(0)
        local statusEl = doc:selectFirst(".status-pill.manga-status-pill")
        if statusEl then
            local classAttr = statusEl:attr("class") or ""
            if classAttr:find("is%-ongoing") then
                status = NovelStatus(0)
            elseif classAttr:find("is%-complete") then
                status = NovelStatus(1)
            elseif classAttr:find("is%-stopped") then
                status = NovelStatus(2)
            end
        end

        local novelInfo = NovelInfo {
            title = title,
            description = description,
            imageURL = imageURL,
            status = status
        }

        if loadChapters then
            local chapters = {}
            local novelSlug = novelURL:gsub("/+$", "")

            local scraped = {}
            local maxScrapedNum = 0
            local rows = doc:select(".ch-list .ch-row")
            for _, row in ipairs(rows) do
                local num = tonumber(row:attr("data-ch-num"))
                local a = row:selectFirst("a")
                if num and a then
                    local titleEl2 = row:selectFirst(".ch-title")
                    scraped[num] = {
                        link = shrink(a:attr("href")),
                        title = titleEl2 and titleEl2:text():trim() or ("الفصل " .. num),
                    }
                    if num > maxScrapedNum then maxScrapedNum = num end
                end
            end

            local totalChapters = maxScrapedNum
            local statBlocks = doc:select(".manga-stat")
            for _, block in ipairs(statBlocks) do
                local label = block:selectFirst(".manga-stat__label")
                if label and label:text():lower():find("فصل") then
                    local val = block:selectFirst(".manga-stat__value")
                    if val then
                        local n = tonumber(val:text())
                        if n and n > totalChapters then totalChapters = n end
                    end
                end
            end

            for i = 1, totalChapters do
                local entry = scraped[i]
                if entry then
                    table.insert(chapters, NovelChapter {
                        link = entry.link,
                        title = entry.title,
                        order = i
                    })
                else
                    table.insert(chapters, NovelChapter {
                        link = novelSlug .. "/الفصل-" .. i .. "/",
                        title = "الفصل " .. i,
                        order = i
                    })
                end
            end

            novelInfo:setChapters(AsList(chapters))
        end

        return novelInfo
    end,

    getPassage = function(chapterURL)
        local url = baseURL .. "/" .. chapterURL
        local html = HttpRequest.GET(url):text()
        local doc = Document(html)

        local content = doc:selectFirst(".reading-content")
        if not content then
            return pageOfText(doc:body():text(), true)
        end

        content:select(".theam-chobf"):remove()
        content:select("input, script, style, iframe, noscript"):remove()

        local paragraphs = content:select("p")
        local text = ""
        for _, p in ipairs(paragraphs) do
            local pText = p:text():trim()
            if pText ~= "" then
                text = text .. pText .. "\n\n"
            end
        end

        if text == "" then
            text = content:text()
        end

        return pageOfText(text, true)
    end,

    search = function(data)
        local query = data[QUERY]
        local page = data[PAGE] + 1
        local url = baseURL .. "/wp-json/theam/v1/library?page=" .. page
            .. "&per_page=24&s=" .. Utils.URLEncode(query)
        local res = json.decode(HttpRequest.GET(url):text())
        local novels = {}
        if res and res.items then
            for _, item in ipairs(res.items) do
                table.insert(novels, novelFromApiItem(item))
            end
        end
        return novels
    end,

    shrinkURL = function(url)
        return shrink(url)
    end,

    expandURL = function(url)
        return baseURL .. "/" .. url
    end
}