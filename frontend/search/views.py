from django.template import Context, loader
from django.http import HttpResponse
from search.models import Sites
import utilits

def index(request):
    t = loader.get_template('search/index.html')
    c = Context({})

    return HttpResponse(t.render(c))

def results(request):
    query = request.GET.get('query', '') 
    page  = int(request.GET.get('page',  '1'))

    if query:
        end = page * 10
        start = end - 10
        all_results = Sites.objects.filter(searchable__contains=query).extra(select={'linkers':'LENGTH(linked_from) - LENGTH(REPLACE(linked_from, " ", ""))'}).order_by('-linkers')
        
        final_page = False
        
        if len(all_results) < end:
            final_page = True

        first_page = False

        if page == 1:
            first_page = True
        
        last_page = 10

        if (len(all_results) / 10) < 10:
            last_page = len(all_results) / 10

        if len(all_results) > last_page * 10:
            last_page += 1

        pages = range(1, last_page + 1)

        if page > 5:
            pages = range(page - 5, page + 6)
        
        if len(pages) == 1:
            pages = []

        sites = all_results[start:end]
        template = loader.get_template('search/search.html')
        
        for i in sites:
            i.title = utilits.title(i.content)

            if not i.title:
                i.title = i.url

            i.description = utilits.description(i.searchable, query)
 
        context  = Context({'sites' : sites, 'results_len' : len(all_results), 'pages' : pages, 'next_page': page + 1, 'prev_page' : page - 1, 'curr_page': page, 'first_page': first_page, 'final_page' : final_page, 'query' : query})
        response = template.render(context)
    else:
        response = "empty search query!"

    return HttpResponse(response)
