from django.conf.urls import  url

from . import views

urlpatterns = [
    url(r'^$',                   views.ThingListView.as_view(),   name='thing-list'),
    url(r'(?P<pk>\d+)/delete/$', views.ThingDeleteView.as_view(), name='thing-delete'),
    url(r'new/$',                views.ThingCreateView.as_view(), name='thing-new'),
]