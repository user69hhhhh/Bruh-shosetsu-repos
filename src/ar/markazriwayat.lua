-- {"id": 99999, "ver": "1.0.0", "libVer": "1.0.0", "author": "WebbuNexus", "repo": "", "dep": []}

local BASE_URL = "https://markazriwayat.com"
local PER_PAGE = 25

-- ====== Helper Functions ======

local function fetch_json(url)
    local resp = HttpRequest(BASE_URL .. url):get()
    return Json.decode(resp.body)
end

local function fetch_html(url)
    return HttpRequest(url):get().body
end

local function extract_chapter_content(html)
    local doc = HtmlParser(html)
    local content = doc:select(".entry-content, .chapter-content, .post-content, article, main")
    if content then
        content:remove("script, style, header, footer, nav, aside")
        local paragraphs = content:select("p")
        local text = ""
        for _, p in ipairs(paragraphs) do
            text = text .. p:text() .. "\n\n"
        end
        return text:trim()
    end
    return doc:body():text():trim()
end

-- ====== getNovels ======

function getNovels(search, page, filters)
    local mode = "all"
    if filters and filters.Mode then
        mode = filters.Mode:lower():gsub(" ", "-")
    end

    local novels = {}
    local totalPages = 1

    if mode == "latest" then
        local url = "/wp-json/theam/v1/latest-chapters?page=" .. page .. "&per_page=" .. PER_PAGE
        local data = fetch_json(url)
        if data.items then
            for _, item in ipairs(data.items) do
                table.insert(novels, {
                    id = tostring(item.id),
                    title = item.title,
                    image = item.cover or "",
                    link = item.permalink or "",
                    description = ""
                })
            end
            totalPages = data.totalPages or 1
        end
    else
        local url = "/wp-json/theam/v1/library?page=" .. page .. "&per_page=" .. PER_PAGE
        local data = fetch_json(url)
        if data.items then
            local items = data.items
            if mode == "ongoing" then
                items = filter(items, function(i) return i.status and i.status.key == "on-going" end)
            elseif mode == "complete" then
                items = filter(items, function(i) return i.status and i.status.key == "end" end)
            elseif mode == "most-chapters" then
                table.sort(items, function(a, b) return (a.chapters_count or 0) > (b.chapters_count or 0) end)
            elseif mode == "most-viewed" then
                table.sort(items, function(a, b) return (a.views or 0) > (b.views or 0) end)
            end
            for _, item in ipairs(items) do
                table.insert(novels, {
                    id = tostring(item.id),
                    title = item.title,
                    image = item.cover or "",
                    link = item.link or item.permalink or "",
                    description = "",
                    chaptersCount = item.chapters_count or 0
                })
            end
            totalPages = data.totalPages or 1
        end
    end

    return {
        novels = novels,
        page = page,
        totalPages = totalPages,
        perPage = PER_PAGE
    }
end

-- ====== getChapters ======

function getChapters(novel)
    local chapters = {}
    local novelUrl = novel.link
    if not novelUrl or novelUrl == "" then
        return {}
    end

    local html = fetch_html(novelUrl)
    local doc = HtmlParser(html)
    local chapterLinks = doc:select("li a[href*='/الفصل-'], li a[href*='/chapter-']")
    if #chapterLinks == 0 then
        chapterLinks = doc:select("a[href*='/الفصل-'], a[href*='/chapter-']")
    end

    for i = #chapterLinks, 1, -1 do
        local a = chapterLinks[i]
        local url = a:attr("href")
        if url:sub(1,1) == "/" then
            url = BASE_URL .. url
        end
        local title = a:text():trim()
        if title == "" then
            title = "الفصل " .. i
        end
        table.insert(chapters, { title = title, url = url })
    end

    if #chapters == 0 and novel.chaptersCount and novel.chaptersCount > 0 then
        local baseLink = novel.link:gsub("/$", "")
        for i = novel.chaptersCount, 1, -1 do
            local url = baseLink .. "/الفصل-" .. i .. "/"
            table.insert(chapters, { title = "الفصل " .. i, url = url })
        end
    end

    return chapters
end

-- ====== getChapterContent ======

function getChapterContent(chapter)
    local html = fetch_html(chapter.url)
    local text = extract_chapter_content(html)
    return {
        content = text,
        content_type = "text/plain"
    }
end

-- ====== getFilters ======

function getFilters()
    return {
        {
            name = "Mode",
            type = "select",
            options = {
                "All",
                "Ongoing",
                "Complete",
                "Most Chapters",
                "Most Viewed",
                "Latest"
            },
            default = "All"
        }
    }
end
