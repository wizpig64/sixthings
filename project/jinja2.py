from __future__ import absolute_import

from django.contrib.staticfiles.storage import staticfiles_storage
from django.core.urlresolvers import reverse
from bootstrap3.forms import render_formset, render_formset_errors, render_form, render_form_errors, render_field, render_label, render_button, render_icon
from jinja2 import Environment


def environment(**options):
    env = Environment(**options)
    env.globals.update({
        'static': staticfiles_storage.url,
        'url': reverse,
        'bootstrap_formset':        render_formset,
        'bootstrap_formset_errors': render_formset_errors,
        'bootstrap_form':           render_form,
        'bootstrap_form_errors':    render_form_errors,
        'bootstrap_field':          render_field,
        'bootstrap_label':          render_label,
        'bootstrap_button':         render_button,
        'bootstrap_icon':           render_icon,
    })
    return env

