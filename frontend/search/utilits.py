from re import compile

def title(document):
    title_regex = compile('<title>(.*?)</title>')
    response    = title_regex.search(document)

    if response is None:
        return ""

    return response.group(1)

def description(document, query):
    str_pos  = document.index(query)
    descript = "" 
    start = str_pos - 60
    end   = str_pos + 60

    if start > 0:
        descript = '...'
    else:
        start = 0

    descript += document[start:end]

    if len(document) > end:
        descript += '...'

    return descript
