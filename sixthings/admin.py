from django.contrib import admin
from .models import Thing


def make_deferred(modeladmin, request, queryset):
    for thing in queryset.all():
        thing.defer()
make_deferred.short_description = "Defer selected things to next day"

class ThingAdmin(admin.ModelAdmin):
    date_hierarchy  = 'date'
    list_display = [
        'id',
        'user',
        'date',
        'text',
        'done',
    ]
    list_filter = [
        'user',
        'date',
        'done',
    ]
    actions = [make_deferred]

admin.site.register(Thing, ThingAdmin)
