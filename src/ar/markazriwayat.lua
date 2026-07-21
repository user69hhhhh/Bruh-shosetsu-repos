-- {"id":99999,"ver":"1.0.0","libVer":"1.0.0","author":"WebbuNexus","dep":["url>=1.0.0","dkjson>=1.0.0"]}

local baseURL = "https://markazriwayat.com"
local baseUrlApi = "https://markazriwayat.com/wp-json/theam/v1"

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
            local url = baseUrlApi .. "/library?page=" .. page .. "&per_page=24"
            local d = json.GET(url)
            
            if not d or not d.items then
                return {}
            end
            
            return map(d.items, function(v)
                -- Extract novel slug from link
                local link = v.link:gsub("^https?://[^/]+/", "")
                return Novel {
                    link = link,
                    title = v.title,
                    imageURL = v.cover or "",
                }
            end)
        end),
        
        Listing("Ongoing", true, function(data)
            local page = data[PAGE] + 1
            local url = baseUrlApi .. "/library?page=" .. page .. "&per_page=24"
            local d = json.GET(url)
            
            if not d or not d.items then
                return {}
            end
            
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
        end),
        
        Listing("Completed", true, function(data)
            local page = data[PAGE] + 1
            local url = baseUrlApi .. "/library?page=" .. page .. "&per_page=24"
            local d = json.GET(url)
            
            if not d or not d.items then
                return {}
            end
            
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
        end),
        
        Listing("Latest Chapters", true, function(data)
            local page = data[PAGE] + 1
            local url = baseUrlApi .. "/latest-chapters?page=" .. page .. "&per_page=24"
            local d = json.GET(url)
            
            if not d or not d.items then
                return {}
            end
            
            return map(d.items, function(v)
                local link = v.permalink:gsub("^https?://[^/]+/", "")
                return Novel {
                    link = link,
                    title = v.title,
                    imageURL = v.cover or "",
                }
            end)
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
            -- Find chapter links - use multiple selectors
            local links = doc:select("li a[href*='/الفصل-'], a[href*='/الفصل-'], .chapter-list a, .wp-manga-chapter a, .list-chapter a, .chapter-link a")
            
            -- Also try finding all links that might be chapters
            if #links == 0 then
                links = doc:select("a[href*='chapter'], a[href*='الفصل']")
            end
            
            local chapters = {}
            local count = 0
            
            -- Reverse order (first chapter first)
            for i = #links, 1, -1 do
                local a = links[i]
                local href = a:attr("href")
                if href then
                    -- Skip non-chapter links
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
            
            -- If no chapters found, try to generate from chapters_count in API
            if #chapters == 0 then
                -- Try to get chapter count from the page
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
        
        -- Find chapter content with multiple selectors
        local content = doc:selectFirst(".entry-content, .chapter-content, .post-content, article, main, .chapter-body, .content")
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
            
            -- If no paragraphs, get all text
            return pageOfText(content:text(), true)
        end
        
        -- Fallback: return body text
        return pageOfText(doc:body():text(), true)
    end,

    search = function(data)
        local query = data[QUERY]
        local page = data[PAGE] + 1
        
        -- Use the library endpoint with search parameter
        local url = baseUrlApi .. "/library?search=" .. qs.encode(query) .. "&page=" .. page .. "&per_page=24"
        local d = json.GET(url)
        
        if not d or not d.items then
            return {}
        end
        
        return map(d.items, function(v)
            local link = v.link:gsub("^https?://[^/]+/", "")
            return Novel {
                title = v.title,
                imageURL = v.cover or "",
                link = link
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