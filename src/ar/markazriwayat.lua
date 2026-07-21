-- {"id":99999,"ver":"1.0.0","libVer":"1.0.0","author":"WebbuNexus","dep":[]}

local baseURL = "https://markazriwayat.com"

return {
    id = 99999,
    name = "Markaz Riwayat",
    baseURL = baseURL,
    hasSearch = true,
    chapterType = ChapterType.HTML,
    imageURL = "https://markazriwayat.com/wp-content/uploads/2023/12/cropped-favicon-192x192.png",
    
    listings = {
        Listing("All Novels", true, function(data)
            local page = data[PAGE] + 1
            local url = baseURL .. "/library/page/" .. page .. "/"
            local doc = Document(HttpRequest.GET(url):text())
            
            -- Find novel containers
            local items = doc:select(".novel-item, .book-item, article, .post-item, .li-row")
            
            -- If no items found, try alternative selectors
            if #items == 0 then
                items = doc:select(".entry-content .row > div, .novel-list .row > div")
            end
            
            if #items == 0 then
                -- Look for any links to novel pages
                local links = doc:select("a[href*='/novel/']")
                local novelLinks = {}
                for _, link in ipairs(links) do
                    local href = link:attr("href")
                    if href and not href:find("/page/") and not href:find("/category/") then
                        table.insert(novelLinks, link)
                    end
                end
                -- Convert links to items
                local wrapped = {}
                for _, link in ipairs(novelLinks) do
                    table.insert(wrapped, link)
                end
                items = wrapped
            end
            
            local novels = {}
            for _, item in ipairs(items) do
                local titleLink = item:selectFirst("a.title, h3 a, .post-title a, .entry-title a")
                if not titleLink then
                    titleLink = item:selectFirst("a[href*='/novel/']")
                end
                
                if titleLink then
                    local href = titleLink:attr("href")
                    if href then
                        local link = href:gsub("^https?://[^/]+/", "")
                        if link ~= "" and not link:find("/page/") then
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
            end
            
            return novels
        end),
        
        Listing("Ongoing", true, function(data)
            local page = data[PAGE] + 1
            local url = baseURL .. "/library/page/" .. page .. "/"
            local doc = Document(HttpRequest.GET(url):text())
            
            local items = doc:select(".novel-item, .book-item, article, .post-item")
            if #items == 0 then
                items = doc:select("a[href*='/novel/']")
                local wrapped = {}
                for _, link in ipairs(items) do
                    table.insert(wrapped, link)
                end
                items = wrapped
            end
            
            local novels = {}
            for _, item in ipairs(items) do
                -- Check status
                local statusEl = item:selectFirst(".status, .novel-status, .post-status")
                local isOngoing = true
                if statusEl then
                    local statusText = statusEl:text():lower()
                    if statusText:find("مكتمل") or statusText:find("complete") or statusText:find("end") then
                        isOngoing = false
                    end
                end
                
                if isOngoing then
                    local titleLink = item:selectFirst("a.title, h3 a, .post-title a, .entry-title a")
                    if not titleLink then
                        titleLink = item:selectFirst("a[href*='/novel/']")
                    end
                    
                    if titleLink then
                        local href = titleLink:attr("href")
                        if href then
                            local link = href:gsub("^https?://[^/]+/", "")
                            if link ~= "" and not link:find("/page/") then
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
                end
            end
            
            return novels
        end),
        
        Listing("Completed", true, function(data)
            local page = data[PAGE] + 1
            local url = baseURL .. "/library/page/" .. page .. "/"
            local doc = Document(HttpRequest.GET(url):text())
            
            local items = doc:select(".novel-item, .book-item, article, .post-item")
            if #items == 0 then
                items = doc:select("a[href*='/novel/']")
                local wrapped = {}
                for _, link in ipairs(items) do
                    table.insert(wrapped, link)
                end
                items = wrapped
            end
            
            local novels = {}
            for _, item in ipairs(items) do
                local statusEl = item:selectFirst(".status, .novel-status, .post-status")
                local isCompleted = false
                if statusEl then
                    local statusText = statusEl:text():lower()
                    if statusText:find("مكتمل") or statusText:find("complete") or statusText:find("end") then
                        isCompleted = true
                    end
                end
                
                if isCompleted then
                    local titleLink = item:selectFirst("a.title, h3 a, .post-title a, .entry-title a")
                    if not titleLink then
                        titleLink = item:selectFirst("a[href*='/novel/']")
                    end
                    
                    if titleLink then
                        local href = titleLink:attr("href")
                        if href then
                            local link = href:gsub("^https?://[^/]+/", "")
                            if link ~= "" and not link:find("/page/") then
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
                end
            end
            
            return novels
        end),
        
        Listing("Latest Chapters", true, function(data)
            local page = data[PAGE] + 1
            local url = baseURL .. "/page/" .. page .. "/"
            local doc = Document(HttpRequest.GET(url):text())
            
            -- Look for latest chapters on homepage
            local items = doc:select(".chapter-item, .post-item, article, .li-row")
            if #items == 0 then
                items = doc:select("a[href*='/الفصل-']")
                local wrapped = {}
                for _, link in ipairs(items) do
                    table.insert(wrapped, link)
                end
                items = wrapped
            end
            
            local novels = {}
            for _, item in ipairs(items) do
                local chapterLink = item:selectFirst("a[href*='/الفصل-'], a[href*='/chapter-']")
                if chapterLink then
                    local href = chapterLink:attr("href")
                    if href then
                        local link = href:gsub("^https?://[^/]+/", "")
                        
                        -- Try to find novel title
                        local titleEl = item:selectFirst(".novel-title, .book-title, .parent-title, .title")
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
            -- Find all chapter links
            local links = doc:select("a[href*='/الفصل-'], a[href*='/chapter-']")
            
            -- Also try chapter list containers
            if #links == 0 then
                links = doc:select(".chapter-list a, .wp-manga-chapter a, .list-chapter a, .chapter-link a")
            end
            
            local chapters = {}
            local count = 0
            
            -- Sort and add chapters (reverse order for first chapter first)
            for i = #links, 1, -1 do
                local a = links[i]
                local href = a:attr("href")
                if href then
                    local link = href:gsub("^https?://[^/]+/", "")
                    count = count + 1
                    local titleText = a:text():trim()
                    if titleText == "" then
                        titleText = "الفصل " .. count
                    end
                    table.insert(chapters, NovelChapter {
                        link = link,
                        title = titleText,
                        order = count
                    })
                end
            end
            
            -- If no chapters found, try to find any link that looks like a chapter
            if #chapters == 0 then
                local allLinks = doc:select("a")
                for _, a in ipairs(allLinks) do
                    local href = a:attr("href")
                    local text = a:text():lower()
                    if href and (href:find("chapter") or text:find("الفصل") or text:find("chapter")) then
                        local link = href:gsub("^https?://[^/]+/", "")
                        count = count + 1
                        table.insert(chapters, NovelChapter {
                            link = link,
                            title = a:text():trim() or "الفصل " .. count,
                            order = count
                        })
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
        
        -- Try multiple content selectors
        local content = doc:selectFirst(".entry-content, .chapter-content, .post-content, article, main, .chapter-body, .content, .txt")
        
        if content then
            -- Remove unwanted elements
            content:remove("script, style, header, footer, nav, aside, .ads, .advertisement, .share, .social, .related, .comments")
            
            -- Try to get paragraphs
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
            
            -- If no paragraphs, get all text with line breaks
            local text = content:text()
            return pageOfText(text, true)
        end
        
        -- Fallback: return body text
        return pageOfText(doc:body():text(), true)
    end,

    search = function(data)
        local query = data[QUERY]
        local page = data[PAGE] + 1
        
        -- Use the library search page
        local url = baseURL .. "/library/page/" .. page .. "/?s=" .. query
        local doc = Document(HttpRequest.GET(url):text())
        
        local items = doc:select(".novel-item, .book-item, article, .post-item")
        if #items == 0 then
            items = doc:select("a[href*='/novel/']")
            local wrapped = {}
            for _, link in ipairs(items) do
                table.insert(wrapped, link)
            end
            items = wrapped
        end
        
        local novels = {}
        for _, item in ipairs(items) do
            local titleLink = item:selectFirst("a.title, h3 a, .post-title a, .entry-title a")
            if not titleLink then
                titleLink = item:selectFirst("a[href*='/novel/']")
            end
            
            if titleLink then
                local href = titleLink:attr("href")
                if href then
                    local link = href:gsub("^https?://[^/]+/", "")
                    if link ~= "" and not link:find("/page/") then
                        local img = item:selectFirst("img")
                        local imageURL = img and img:attr("src") or ""
                        
                        table.insert(novels, Novel {
                            title = titleLink:text():trim(),
                            imageURL = imageURL,
                            link = link
                        })
                    end
                end
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