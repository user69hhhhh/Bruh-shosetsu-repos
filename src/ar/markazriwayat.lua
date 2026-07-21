-- {"id":99999,"ver":"1.0.0","libVer":"1.0.0","author":"WebbuNexus","dep":["url>=1.0.0","dkjson>=1.0.0"]}

local baseURL = "https://markazriwayat.com"
local baseUrlApi = "https://markazriwayat.com/library/"

local json = Require("dkjson")
local qs = Require("url").querystring

return {
    id = 99999,
    name = "Markaz Riwayat - مركز الروايات",
    baseURL = baseURL,
    hasSearch = true,
    chapterType = ChapterType.HTML,
    imageURL = "https://markazriwayat.com/wp-content/uploads/2023/12/cropped-favicon-192x192.png",
    
    listings = {
        Listing("All Novels", true, function(data)
            local page = data[PAGE] + 1
            -- Use the public library page
            local url = baseURL .. "/library/page/" .. page .. "/"
            local doc = Document(HttpRequest.GET(url):text())
            
            -- Find novel items on the page
            local items = doc:select(".novel-item, .book-item, .post-item, article, .li-row, .row-item")
            
            if #items == 0 then
                -- Fallback: try different selectors
                items = doc:select(".entry-content .row > div, .novel-list > div, .manga-list > div")
            end
            
            -- If still no items, try to find any links to novels
            if #items == 0 then
                items = doc:select("a[href*='/novel/']")
                -- Wrap each link as an item
                local wrapped = {}
                for _, link in ipairs(items) do
                    table.insert(wrapped, link:parent())
                end
                items = wrapped
            end
            
            local novels = {}
            for _, item in ipairs(items) do
                -- Find title link
                local titleLink = item:selectFirst("a.title, a.novel-title, h3 a, .post-title a, .entry-title a")
                if not titleLink then
                    titleLink = item:selectFirst("a[href*='/novel/']")
                end
                
                if titleLink then
                    local href = titleLink:attr("href")
                    local link = href and href:gsub("^https?://[^/]+/", "") or ""
                    
                    -- Find image
                    local img = item:selectFirst("img")
                    local imageURL = img and img:attr("src") or ""
                    
                    -- Find chapter count
                    local countEl = item:selectFirst(".chapter-count, .chapters, .count, .chapters-count")
                    local chapterCount = countEl and countEl:text():match("%d+") or "0"
                    
                    table.insert(novels, Novel {
                        link = link,
                        title = titleLink:text():trim(),
                        imageURL = imageURL,
                    })
                end
            end
            
            -- If no novels found via scraping, fallback to API
            if #novels == 0 then
                local apiUrl = baseUrlApi .. "/library?page=" .. page .. "&per_page=24"
                local d = json.GET(apiUrl)
                if d and d.items then
                    return map(d.items, function(v)
                        local link = v.link:gsub("^https?://[^/]+/", "")
                        return Novel {
                            link = link,
                            title = v.title,
                            imageURL = v.cover or "",
                        }
                    end)
                end
            end
            
            return novels
        end),
        
        Listing("Ongoing", true, function(data)
            -- Use the public library page with filtering
            local page = data[PAGE] + 1
            local url = baseURL .. "/library/page/" .. page .. "/"
            local doc = Document(HttpRequest.GET(url):text())
            
            local items = doc:select(".novel-item, .book-item, .post-item, article")
            if #items == 0 then
                items = doc:select("a[href*='/novel/']")
                local wrapped = {}
                for _, link in ipairs(items) do
                    table.insert(wrapped, link:parent())
                end
                items = wrapped
            end
            
            local novels = {}
            for _, item in ipairs(items) do
                -- Check if it has "ongoing" status
                local statusEl = item:selectFirst(".status, .novel-status, .post-status")
                local isOngoing = true
                if statusEl then
                    local statusText = statusEl:text():lower()
                    if statusText:find("مكتمل") or statusText:find("complete") then
                        isOngoing = false
                    end
                end
                
                if isOngoing then
                    local titleLink = item:selectFirst("a.title, a.novel-title, h3 a, a[href*='/novel/']")
                    if titleLink then
                        local href = titleLink:attr("href")
                        local link = href and href:gsub("^https?://[^/]+/", "") or ""
                        local img = item:selectFirst("img")
                        local imageURL = img and img:attr("src") or ""
                        
                        table.insert(novels, Novel {
                            link = link,
                            title = titleLink:text():trim(),
                            imageURL = imageURL,
                        })
                    end
                end
            end
            
            -- If no ongoing novels found, use API
            if #novels == 0 then
                local apiUrl = baseUrlApi .. "/library?page=" .. page .. "&per_page=24"
                local d = json.GET(apiUrl)
                if d and d.items then
                    local ongoing = filter(d.items, function(v)
                        return v.status and v.status.key == "on-going"
                    end)
                    return map(ongoing, function(v)
                        local link = v.link:gsub("^https?://[^/]+/", "")
                        return Novel {
                            link = link,
                            title = v.title,
                            imageURL = v.cover or "",
                        }
                    end)
                end
            end
            
            return novels
        end),
        
        Listing("Completed", true, function(data)
            local page = data[PAGE] + 1
            local url = baseURL .. "/library/page/" .. page .. "/"
            local doc = Document(HttpRequest.GET(url):text())
            
            local items = doc:select(".novel-item, .book-item, .post-item, article")
            if #items == 0 then
                items = doc:select("a[href*='/novel/']")
                local wrapped = {}
                for _, link in ipairs(items) do
                    table.insert(wrapped, link:parent())
                end
                items = wrapped
            end
            
            local novels = {}
            for _, item in ipairs(items) do
                local statusEl = item:selectFirst(".status, .novel-status, .post-status")
                local isCompleted = false
                if statusEl then
                    local statusText = statusEl:text():lower()
                    if statusText:find("مكتمل") or statusText:find("complete") then
                        isCompleted = true
                    end
                end
                
                if isCompleted then
                    local titleLink = item:selectFirst("a.title, a.novel-title, h3 a, a[href*='/novel/']")
                    if titleLink then
                        local href = titleLink:attr("href")
                        local link = href and href:gsub("^https?://[^/]+/", "") or ""
                        local img = item:selectFirst("img")
                        local imageURL = img and img:attr("src") or ""
                        
                        table.insert(novels, Novel {
                            link = link,
                            title = titleLink:text():trim(),
                            imageURL = imageURL,
                        })
                    end
                end
            end
            
            if #novels == 0 then
                local apiUrl = baseUrlApi .. "/library?page=" .. page .. "&per_page=24"
                local d = json.GET(apiUrl)
                if d and d.items then
                    local completed = filter(d.items, function(v)
                        return v.status and v.status.key == "end"
                    end)
                    return map(completed, function(v)
                        local link = v.link:gsub("^https?://[^/]+/", "")
                        return Novel {
                            link = link,
                            title = v.title,
                            imageURL = v.cover or "",
                        }
                    end)
                end
            end
            
            return novels
        end),
        
        Listing("Latest Chapters", true, function(data)
            local page = data[PAGE] + 1
            -- Use the latest chapters page
            local url = baseURL .. "/latest-chapters/page/" .. page .. "/"
            local doc = Document(HttpRequest.GET(url):text())
            
            -- Find chapter items
            local items = doc:select(".chapter-item, .post-item, article, .li-row")
            if #items == 0 then
                items = doc:select("a[href*='/الفصل-']")
                local wrapped = {}
                for _, link in ipairs(items) do
                    table.insert(wrapped, link:parent())
                end
                items = wrapped
            end
            
            local novels = {}
            for _, item in ipairs(items) do
                local chapterLink = item:selectFirst("a[href*='/الفصل-'], a[href*='/chapter-']")
                if chapterLink then
                    local href = chapterLink:attr("href")
                    local link = href and href:gsub("^https?://[^/]+/", "") or ""
                    
                    -- Try to find novel title
                    local titleEl = item:selectFirst(".novel-title, .book-title, .parent-title")
                    local title = titleEl and titleEl:text():trim() or "Latest Chapter"
                    
                    -- Try to find novel image
                    local img = item:selectFirst("img")
                    local imageURL = img and img:attr("src") or ""
                    
                    table.insert(novels, Novel {
                        link = link,
                        title = title,
                        imageURL = imageURL,
                    })
                end
            end
            
            -- Fallback to API
            if #novels == 0 then
                local apiUrl = baseUrlApi .. "/latest-chapters?page=" .. page .. "&per_page=24"
                local d = json.GET(apiUrl)
                if d and d.items then
                    return map(d.items, function(v)
                        local link = v.permalink:gsub("^https?://[^/]+/", "")
                        return Novel {
                            link = link,
                            title = v.title,
                            imageURL = v.cover or "",
                        }
                    end)
                end
            end
            
            return novels
        end),
    },

    parseNovel = function(novelURL, loadChapters)
        local url = baseURL .. "/" .. novelURL
        local doc = Document(HttpRequest.GET(url):text())
        
        -- Get title
        local titleEl = doc:selectFirst(".post-title, .entry-title, h1, .novel-title")
        local title = titleEl and titleEl:text() or novelURL
        
        -- Get image
        local imgEl = doc:selectFirst(".post-thumbnail img, .entry-content img, img.wp-post-image, .novel-cover img")
        local imageURL = imgEl and imgEl:attr("src") or ""
        
        -- Get description
        local descEl = doc:selectFirst(".entry-content p, .post-content p, .summary, .description, .novel-description")
        local description = descEl and descEl:text() or ""
        
        -- Get status
        local statusText = doc:selectFirst(".status, .novel-status, .post-status")
        local status = NovelStatus(0)
        if statusText then
            local text = statusText:text():lower()
            if text:find("مكتمل") or text:find("complete") then
                status = NovelStatus(1)
            elseif text:find("متوقف") or text:find("hiatus") then
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
            -- Find chapter links
            local links = doc:select("li a[href*='/الفصل-'], a[href*='/الفصل-'], .chapter-list a, .wp-manga-chapter a, .list-chapter a, .chapter-link a")
            
            if #links == 0 then
                links = doc:select("a[href*='chapter'], a[href*='الفصل']")
            end
            
            local chapters = {}
            local count = 0
            
            for i = #links, 1, -1 do
                local a = links[i]
                local href = a:attr("href")
                if href then
                    if href:find("/الفصل-") or href:find("/chapter-") or href:find("chapter") then
                        local link = href:gsub("^https?://[^/]+/", "")
                        local titleText = a:text():trim()
                        if titleText == "" then
                            count = count + 1
                            titleText = "الفصل " .. count
                        else
                            count = count + 1
                        end
                        table.insert(chapters, NovelChapter {
                            link = link,
                            title = titleText,
                            order = count
                        })
                    end
                end
            end
            
            -- Fallback: generate from chapter count if available
            if #chapters == 0 then
                local countEl = doc:selectFirst(".chapters-count, .chapter-count, .count-chapters, .total-chapters")
                if countEl then
                    local num = tonumber(countEl:text():match("%d+"))
                    if num and num > 0 then
                        for i = num, 1, -1 do
                            local link = novelURL:gsub("/$", "") .. "/الفصل-" .. i .. "/"
                            table.insert(chapters, NovelChapter {
                                link = link,
                                title = "الفصل " .. i,
                                order = i
                            })
                        end
                    end
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
        
        local content = doc:selectFirst(".entry-content, .chapter-content, .post-content, article, main, .chapter-body, .content")
        if content then
            content:remove("script, style, header, footer, nav, aside, .ads, .advertisement, .share, .social, .related, .comments")
            
            local paragraphs = content:select("p")
            if #paragraphs > 0 then
                local text = ""
                for _, p in ipairs(paragraphs) do
                    local pText = p:text():trim()
                    if pText ~= "" then
                        text = text .. pText .. "\n\n"
                    end
                end
                if text ~= "" then
                    return pageOfText(text, true)
                end
            end
            
            return pageOfText(content:text(), true)
        end
        
        return pageOfText(doc:body():text(), true)
    end,

    search = function(data)
        local query = data[QUERY]
        local page = data[PAGE] + 1
        
        -- Use the library page with search parameter
        local url = baseURL .. "/library/?s=" .. qs.encode(query) .. "&page=" .. page
        local doc = Document(HttpRequest.GET(url):text())
        
        local items = doc:select(".novel-item, .book-item, .post-item, article")
        if #items == 0 then
            items = doc:select("a[href*='/novel/']")
            local wrapped = {}
            for _, link in ipairs(items) do
                table.insert(wrapped, link:parent())
            end
            items = wrapped
        end
        
        local novels = {}
        for _, item in ipairs(items) do
            local titleLink = item:selectFirst("a.title, a.novel-title, h3 a, a[href*='/novel/']")
            if titleLink then
                local href = titleLink:attr("href")
                local link = href and href:gsub("^https?://[^/]+/", "") or ""
                local img = item:selectFirst("img")
                local imageURL = img and img:attr("src") or ""
                
                table.insert(novels, Novel {
                    title = titleLink:text():trim(),
                    imageURL = imageURL,
                    link = link
                })
            end
        end
        
        -- Fallback to API search
        if #novels == 0 then
            local apiUrl = baseUrlApi .. "/library?search=" .. qs.encode(query) .. "&page=" .. page .. "&per_page=24"
            local d = json.GET(apiUrl)
            if d and d.items then
                return map(d.items, function(v)
                    local link = v.link:gsub("^https?://[^/]+/", "")
                    return Novel {
                        title = v.title,
                        imageURL = v.cover or "",
                        link = link
                    }
                end)
            end
        end
        
        return novels
    end,

    shrinkURL = function(url)
        return url:gsub("^https?://[^/]+/", "")
    end,
    
    expandURL = function(url)
        return baseURL .. "/" .. url
    end
}