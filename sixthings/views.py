from django.views import generic
from .models import Thing

class ThingListView(generic.ListView):
    model = Thing

class ThingDeleteView(generic.DeleteView):
    model = Thing
    success_url = '/'

class ThingCreateView(generic.CreateView):
    model = Thing
    fields = [
        'user',
        'text',
    ]
    success_url = '/'
