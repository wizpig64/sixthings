from django.forms import ModelForm
from .models import Thing

# Create the form class.
class ThingCreateForm(ModelForm):
    class Meta:
        model = Thing
        fields = [
            'date',
            'text',
        ]

    def __init__(self, user, *args, **kwargs):
        super(ThingCreateForm, self).__init__(*args, **kwargs)
        self._user = user

    def save(self, commit=True, **kwargs):
        m = super(ThingCreateForm, self).save(commit=False, **kwargs)
        self.instance.user = self._user
        if commit:
            m.save()
        return m
