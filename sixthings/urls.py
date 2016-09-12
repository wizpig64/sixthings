from django.conf.urls import  url
from django.contrib.auth.decorators import login_required as l

from . import views

urlpatterns = [
    url(r'^$',                   l(views.ThingListView.as_view()),   name='thing-list'),
    url(r'(?P<pk>\d+)/done/$',   l(views.ThingDoneView.as_view()),   name='thing-done'),
    url(r'(?P<pk>\d+)/undone/$', l(views.ThingUndoneView.as_view()), name='thing-undone'),
    url(r'(?P<pk>\d+)/defer/$',  l(views.ThingDeferView.as_view()),  name='thing-defer'),
    url(r'(?P<pk>\d+)/delete/$', l(views.ThingDeleteView.as_view()), name='thing-delete'),
    url(r'new/$',                l(views.ThingCreateView.as_view()), name='thing-new'),
]