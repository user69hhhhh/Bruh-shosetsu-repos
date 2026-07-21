-- {"id":99999,"ver":"1.0.0","libVer":"1.0.0","author":"WebbuNexus","dep":["url>=1.0.0","dkjson>=1.0.0"]}

local baseURL = "https://markazriwayat.com"
local baseUrlApi = "https://markazriwayat.com/wp-json/theam/v1"

---@type dkjson
local json = Require("dkjson")
local qs = Require("url").querystring

return {
    id = 99999,
    name = "Markaz Riwayat - مركز الروايات",
    baseURL = baseURL,
    hasSearch = true,
    chapterType = ChapterType.HTML,
    
    listings = {
        Listing("All Novels", true, function(data)
            local page = data[PAGE] + 1
            local d = json.GET(baseUrlApi .. "/library?page=" .. page .. "&per_page=25")
            
            return map(d.items or {}, function(v)
                return Novel {
                    link = v.permalink or v.link or "",
                    title = v.title,
                    imageURL = v.cover or "",
                }
            end)
        end),
        
        Listing("Latest Chapters", true, function(data)
            local page = data[PAGE] + 1
            local d = json.GET(baseUrlApi .. "/latest-chapters?page=" .. page .. "&per_page=25")
            
            return map(d.items or {}, function(v)
                return Novel {
                    link = v.permalink or "",
                    title = v.title,
                    imageURL = v.cover or "",
                }
            end)
        end),
        
        Listing("Ongoing", true, function(data)
            local page = data[PAGE] + 1
            local d = json.GET(baseUrlApi .. "/library?page=" .. page .. "&per_page=25")
            
            local ongoing = filter(d.items or {}, function(v)
                return v.status and v.status.key == "on-going"
            end)
            
            return map(ongoing, function(v)
                return Novel {
                    link = v.permalink or v.link or "",
                    title = v.title,
                    imageURL = v.cover or "",
                }
            end)
        end),
        
        Listing("Completed", true, function(data)
            local page = data[PAGE] + 1
            local d = json.GET(baseUrlApi .. "/library?page=" .. page .. "&per_page=25")
            
            local completed = filter(d.items or {}, function(v)
                return v.status and v.status.key == "end"
            end)
            
            return map(completed, function(v)
                return Novel {
                    link = v.permalink or v.link or "",
                    title = v.title,
                    imageURL = v.cover or "",
                }
            end)
        end),
    },

    parseNovel = function(novelURL, loadChapters)
        -- Fetch novel details from the page itself (no API for details)
        local doc = Document(HttpRequest.GET(baseURL .. "/" .. novelURL):text())
        
        -- Get title
        local title = doc:selectFirst(".post-title, .entry-title, h1"):text() or ""
        
        -- Get image
        local img = doc:selectFirst(".post-thumbnail img, .entry-content img, img.wp-post-image")
        local imageURL = img and img:attr("src") or ""
        
        -- Get description
        local desc = doc:selectFirst(".entry-content p, .post-content p, .summary, .description")
        local description = desc and desc:text() or ""
        
        local novelInfo = NovelInfo {
            title = title,
            description = description,
            imageURL = imageURL,
            status = NovelStatus(
                string.find(title, "مكتمل") and 1 or
                string.find(title, "متوقف") and 2 or 0
            )
        }

        if loadChapters then
            -- Scrape chapter links from the page
            local chapterElements = doc:select("li a[href*='/الفصل-'], li a[href*='/chapter-'], a[href*='/الفصل-']")
            
            if #chapterElements == 0 then
                -- Try alternative selectors
                chapterElements = doc:select(".chapter-list a, .wp-manga-chapter a, .list-chapter a")
            end
            
            local chapters = {}
            for i = #chapterElements, 1, -1 do
                local a = chapterElements[i]
                local href = a:attr("href")
                if href then
                    -- Remove domain if present
                    local link = href:gsub("^https?://[^/]+/", "")
                    local titleText = a:text():trim()
                    if titleText == "" then
                        titleText = "الفصل " .. i
                    end
                    table.insert(chapters, NovelChapter {
                        link = link,
                        title = titleText,
                        order = i
                    })
                end
            end
            
            novelInfo:setChapters(AsList(chapters))
        end

        return novelInfo
    end,

    getPassage = function(chapterURL)
        -- Fetch chapter content
        local html = HttpRequest.GET(baseURL .. "/" .. chapterURL):text()
        local doc = Document(html)
        
        -- Find chapter content
        local content = doc:selectFirst(".entry-content, .chapter-content, .post-content, article, main")
        if content then
            -- Remove unwanted elements
            content:remove("script, style, header, footer, nav, aside, .ads, .advertisement")
        else
            content = doc:selectFirst("body")
        end
        
        -- Process paragraphs
        local paragraphs = content:select("p")
        if #paragraphs > 0 then
            local text = ""
            for _, p in ipairs(paragraphs) do
                text = text .. p:text() .. "\n\n"
            end
            return pageOfText(text, true)
        end
        
        return pageOfText(content:text(), true)
    end,

    search = function(data)
        local query = data[QUERY]
        local page = data[PAGE] + 1
        
        -- Try to search using the library endpoint with search parameter
        local d = json.GET(baseUrlApi .. "/library?search=" .. qs.encode(query) .. "&page=" .. page .. "&per_page=25")
        
        return map(d.items or {}, function(v)
            return Novel {
                title = v.title,
                imageURL = v.cover or "",
                link = v.permalink or v.link or ""
            }
        end)
    end,

    shrinkURL = function(url)
        return url:gsub("^https?://[^/]+/", "")
    end,
    
    expandURL = function(url)
        return baseURL .. "/" .. url
    end
}