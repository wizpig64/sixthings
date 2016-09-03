from django.contrib import admin
from .models import Thing

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

admin.site.register(Thing, ThingAdmin)
