use spry, curl, xml
import spry/[IRC, Message, Prefix]
import curl/[Curl, Highlevel]
import xml/[Xml, XPath]
import structs/[List, ArrayList], text/StringTokenizer

main: func {
    bot := IRC new("sprink", "sprink", "a spry little IRC bot", "localhost", 6667)

    bot on("send", |irc, msg|
        ">> " print()
        msg toString() println()
    )

    bot on("all", |irc, msg|
        msg toString() println()
    )

    bot on("001", |irc, msg|
        irc join("#programming,#offtopic,#bots,#minecraft")
    )

    bot on("PRIVMSG", |irc, msg|
        target := msg params[0]
        if(target startsWith?('#'))
            irc runCallback("channel message", msg)
        else
            irc runCallback("private message", msg)
    )

    bot on("channel message", |irc, msg|
        channel := msg params[0]
        if(msg params[1] startsWith?(irc nickname)) {
            words := msg params[1] split(' ', 3)
            words size toString() println()
            words each(|word| word print(); ": " print(); word size toString() println())
            first := words[1]
            match first {
                case "!channels" =>
                    buf := Buffer new()
                    for(c in irc channels)
                        buf append(c) .append(' ')
                    irc privmsg(channel, msg prefix nick + ": " + buf toString())
                case "!ping" =>
                    irc privmsg(channel, msg prefix nick + ": pong")
                case "!join" =>
                    chan := words[2]
                    if(irc channels contains?(chan)) {
                        irc privmsg(channel, msg prefix nick + ": I'm already in " + chan + ".")
                    } else {
                        irc join(chan)
                        irc privmsg(channel, msg prefix nick + ": Consider it done.")
                    }
                case "!part" =>
                    chan := words[2]
                    if(irc channels contains?(chan)) {
                        irc part(chan)
                        irc privmsg(channel, msg prefix nick + ": Consider it done.")
                    } else {
                        irc privmsg(channel, msg prefix nick + ": I'm not in " + chan + ".")
                    }
                case =>
                    code := msg params[1] split(' ', 2)[1]
                    result := frinkEval(code)
                    if(result) {
                        if(result size > 450)
                            result = result[0..444] + " (...)"
                        irc privmsg(channel, msg prefix nick + ": " + result)
                    } else {
                        irc privmsg(channel, msg prefix nick + ": No results found on " + frinkUrl(code))
                    }
            }
        }
    )

    bot run()
}

frinkUrl: func (code: String) -> String {
    "http://futureboy.us/fsp/frink.fsp?fromVal=" + Curl escape(code)
}

frinkEval: func (code: String) -> String {
    url := frinkUrl(code)
    request := HTTPRequest new(url) .perform()
    doc := HtmlDoc new(request getString(), "frink.fsp")
    resultList := doc evalXPath("//a[@name=\"results\"]")
    if(resultList size > 0 && resultList[0]@ children && resultList[0]@ children@ content) {
        resultNode := resultList[0]
        result := resultNode@ children@ content toString()
        result
    } else {
        null
    }
}
