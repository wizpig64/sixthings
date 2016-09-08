import datetime
from django.core.exceptions import PermissionDenied
from django.http import HttpResponseRedirect
from django.views import generic
from .forms import ThingCreateForm
from .models import Thing

class ThingListView(generic.ListView):
    model = Thing

    def get_queryset(self):
        queryset = super(ThingListView, self).get_queryset()
        return queryset.filter(user=self.request.user)

    def get_context_data(self, **kwargs):
        today = datetime.date.today()
        yesterday = today - datetime.timedelta(1)
        tomorrow = today + datetime.timedelta(1)

        queryset = kwargs.pop('object_list', self.object_list)

        days = [{
            'name':   'yesterday',
            'date':   yesterday,
            'things': queryset.filter(date=yesterday),
        }, {
            'name':   'today',
            'date':   today,
            'things': queryset.filter(date=today),
        }, {
            'name':   'tomorrow',
            'date':   tomorrow,
            'things': queryset.filter(date=tomorrow),
        }]

        for day in days:
            day['can_add'] = True if day['things'].count() < 6 else False

        for i, day in enumerate(days):
            day['can_defer'] = days[i + 1]['can_add'] if i + 1 < len(days) else False

        return super(ThingListView, self).get_context_data(days=days, **kwargs)

class ThingDeleteView(generic.DeleteView):
    model = Thing
    success_url = '/'

class ThingDoneView(ThingDeleteView):
    def delete(self, request, *args, **kwargs):
        """
        modified delete() to just mark as done
        """
        self.object = self.get_object()
        if self.object.user != self.request.user:
            raise PermissionDenied
        success_url = self.get_success_url()
        self.object.done = True
        self.object.save()
        return HttpResponseRedirect(success_url)

class ThingUndoneView(ThingDeleteView):
    def delete(self, request, *args, **kwargs):
        """
        modified delete() to just mark as undone
        """
        self.object = self.get_object()
        if self.object.user != self.request.user:
            raise PermissionDenied
        success_url = self.get_success_url()
        self.object.done = False
        self.object.save()
        return HttpResponseRedirect(success_url)

class ThingDeferView(ThingDeleteView):
    def delete(self, request, *args, **kwargs):
        """
        modified delete() to just copy to tomorrow
        """
        self.object = self.get_object()
        if self.object.user != self.request.user:
            raise PermissionDenied
        success_url = self.get_success_url()
        Thing.objects.create(
            user=self.object.user,
            date=self.object.date + datetime.timedelta(1),
            text=self.object.text,
            done=self.object.done,
        )
        return HttpResponseRedirect(success_url)

class ThingCreateView(generic.CreateView):
    model = Thing
    form_class = ThingCreateForm
    success_url = '/'

    def get_form_kwargs(self):
        kwargs = super(ThingCreateView, self).get_form_kwargs()
        kwargs.update({'user': self.request.user})
        return kwargs
