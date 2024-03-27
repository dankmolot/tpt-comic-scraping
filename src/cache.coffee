import Database from "better-sqlite3"
import Logger from "@ptkdev/logger"

logger = new Logger()
cache = new Database "cache.db", verbose: (msg) -> logger.debug msg, "sql"

process.on "exit", () => cache.close()

migrate = ->
    logger.info "Migrating database...", "cache"
    cache.exec "create table if not exists metadata ( key text primary key unique, value text )"
    cache.exec "insert or ignore into metadata values ( 'version', '0' )"
    version = parseInt cache.prepare("select value from metadata where key = 'version'").get().value

    # Add comic page metadata cache
    if version < 1
        cache.exec "create table comic_page ( url primary key unique, etag text, data text )"
        version = 1

    # Set version
    cache.prepare("update metadata set value = ? where key = 'version'").run(version)
    logger.info "Database successfully migrated to version #{version}", "cache"


export addComicPage = (url, etag, data) ->
    cache.prepare("insert or replace into comic_page values ( ?, ?, ? )").run(url, etag, JSON.stringify data)

export getComicPage = (url) ->
    result = cache.prepare("select etag, data from comic_page where url = ?").get(url)
    result.data = JSON.parse result.data if result
    return result


migrate()
