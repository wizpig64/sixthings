import datetime
from django.views import generic
from django.http import HttpResponseRedirect
from .models import Thing

class ThingListView(generic.ListView):
    model = Thing
    def get_context_data(self, **kwargs):
        today = datetime.date.today()
        yesterday = today - datetime.timedelta(1)
        tomorrow = today + datetime.timedelta(1)

        queryset = kwargs.pop('object_list', self.object_list)

        context = {
            'yesterday': {
                'date': yesterday,
                'things': queryset.filter(date=yesterday),
            },
            'today': {
                'date': today,
                'things': queryset.filter(date=today),
            },
            'tomorrow': {
                'date': tomorrow,
                'things': queryset.filter(date=tomorrow),
            },
        }
        context.update(kwargs)
        return super(ThingListView, self).get_context_data(**context)

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
