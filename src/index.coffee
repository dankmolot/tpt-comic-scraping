import * as cheerio from "cheerio"
import Logger from "@ptkdev/logger"
import fs from "fs/promises"
import * as cache from "./cache.js"

PAGES = 10 # Number of how many pages to fetch
DELAY = 0 # Delay between requests in milliseconds

logger = new Logger()

sleep = (ms) -> new Promise (resolve) -> setTimeout resolve, ms

parseImageUrl = (img_url) ->
    parts = img_url.split "/"
    meta = {}
    meta.url = img_url
    meta.filename = parts.pop()
    meta.id = parts.pop()
    meta.month = parts.pop()
    meta.year = parts.pop()
    return meta
    
parseComicPage = (html) ->
    $ = cheerio.load html
    $container = $ "div[type='comic']"
    $img = $container.find "img"
    $a = $container.find "a"

    meta = parseImageUrl $img.attr "src"
    meta.next = "https://explosm.net" + $a.attr "href"
    return meta


fetchComicPage = (url) ->
    result = cache.getComicPage url

    res = await fetch url, headers: { "If-None-Match": result?.etag }
    logger.debug "#{res.url} #{res.statusText}", "getPage"
    if res.status == 304
        return result.data

    if not res.ok
        return

    etag = res.headers.get "etag"
    meta = parseComicPage await res.text()

    cache.addComicPage url, etag, meta
    return meta

fetchPages = (start_url, number, delay) ->
    pages = []
    current_page = start_url
    for i in [0...number]
        meta = await fetchComicPage current_page
        break if not meta
        pages.push meta
        current_page = meta.next
        await sleep delay

    return pages

downloadImage = (url, filename) ->
    if await fs.access(filename).then(-> true).catch(-> false)
        logger.debug "File already exists: #{filename}", "downloader"
        return

    res = await fetch url
    if not res.ok
        logger.error "Failed to download #{filename}", "downloader"
        return

    logger.debug "#{res.url} #{res.statusText}", "downloader"
    await fs.writeFile filename, res.body

logger.info "Fetching #{PAGES} latest pages...", "main"
pages = await fetchPages "https://explosm.net/comics/latest", PAGES, DELAY

await fs.mkdir "comics", recursive: true

logger.info "Downloading #{pages.length} pages...", "main"
for meta in pages
    await downloadImage meta.url, "comics/#{meta.year}-#{meta.month}-#{meta.id}-#{meta.filename}"

logger.info "Successfully downloaded #{pages.length} pages", "main"
