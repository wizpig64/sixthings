from django.conf.urls import  url

from . import views

urlpatterns = [
    url(r'^$',                   views.ThingListView.as_view(),   name='thing-list'),
    url(r'(?P<pk>\d+)/done/$',   views.ThingDoneView.as_view(),   name='thing-done'),
    url(r'(?P<pk>\d+)/undone/$', views.ThingUndoneView.as_view(), name='thing-undone'),
    url(r'(?P<pk>\d+)/defer/$',  views.ThingDeferView.as_view(),  name='thing-defer'),
    url(r'(?P<pk>\d+)/delete/$', views.ThingDeleteView.as_view(), name='thing-delete'),
    url(r'new/$',                views.ThingCreateView.as_view(), name='thing-new'),
]