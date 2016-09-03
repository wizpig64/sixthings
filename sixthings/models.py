from __future__ import unicode_literals

import datetime
from django.conf import settings
from django.db import models

class Thing(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL)
    date = models.DateField(default=datetime.date.today)
    text = models.CharField(max_length=1024)
    done = models.BooleanField(default=False)
