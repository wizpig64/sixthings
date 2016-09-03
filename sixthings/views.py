from django.views import generic
from django.http import HttpResponseRedirect
from .models import Thing

class ThingListView(generic.ListView):
    model = Thing

class ThingDeleteView(generic.DeleteView):
    model = Thing
    success_url = '/'

class ThingDoneView(generic.DeleteView):
    model = Thing
    success_url = '/'
    def delete(self, request, *args, **kwargs):
        """
        modified delete() to just mark as done
        """
        self.object = self.get_object()
        success_url = self.get_success_url()
        self.object.done = True
        self.object.save()
        return HttpResponseRedirect(success_url)

class ThingCreateView(generic.CreateView):
    model = Thing
    fields = [
        'user',
        'text',
    ]
    success_url = '/'
