from __future__ import unicode_literals

import datetime
from django.conf import settings
from django.db import models

DONE_CHOICES = (
    (False, 'No'),
    (True, 'Yes'),
    (None, 'Deferred'),
)

class Thing(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL)
    date = models.DateField(default=datetime.date.today)
    text = models.CharField(max_length=1024)
    done = models.NullBooleanField(default=False, choices=DONE_CHOICES)

    @property
    def deferred(self):
        return self.done is None

    def defer(self):
        Thing.objects.create(
            user=self.user,
            date=self.date + datetime.timedelta(1),
            text=self.text,
        )
        self.done = None
        self.save()
