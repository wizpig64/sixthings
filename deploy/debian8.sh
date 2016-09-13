#!/bin/bash
#Install sixthings on a new debian 8 server by running this script as root.
# wget -O- https://raw.github.com/wizpig64/sixthings/master/deploy/debian8.sh | sh
#Note: Systemd will be made the system's init provider.
#Note: Project will install to /var/www/sixthings.

#Variables - when deploying, customize these and settings_local.py below.
SITE_NAME="Six Things"
SITE_DOMAIN=sixthings.example.com
SUPERUSER_USERNAME=admin
SUPERUSER_PASSWORD=imsosuper
SUPERUSER_EMAIL=admin@$SITE_DOMAIN

DEBUG=False
ALLOWED_HOSTS="['$SITE_DOMAIN', ]"
SECRET_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#$%^&*(-_=+)' | fold -w 50 | head -n 1)

DEPLOY_DIR=/var/www-data/sixthings
GIT_REPO=https://github.com/wizpig64/sixthings.git

#Check for root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

#Install system requirements
apt-get update
apt-get install -y \
    build-essential \
    git \
    nginx \
    python-dev \
    systemd-sysv \
    virtualenv \

#Download project
mkdir -p $DEPLOY_DIR
cd $DEPLOY_DIR
git clone $GIT_REPO .
virtualenv .
source bin/activate
pip install -r requirements.txt

#Generate local settings
cat <<EOF > project/settings_local.py
#Local settings for $SITE_NAME

DEBUG=$DEBUG
SECRET_KEY='$SECRET_KEY'
ALLOWED_HOSTS=$ALLOWED_HOSTS

# DATABASES = {
#     'default': {
#         'ENGINE': 'django.db.backends.sqlite3',
#         'NAME': os.path.join(BASE_DIR, 'db.sqlite3'),
#     }
# }

# DEFAULT_FROM_EMAIL = '$SUPERUSER_EMAIL'
# SERVER_EMAIL = '$SUPERUSER_EMAIL'
# EMAIL_HOST = '$SITE_DOMAIN'
# EMAIL_HOST_USER = '$SUPERUSER_EMAIL'
# EMAIL_HOST_PASSWORD = 'password'
# EMAIL_PORT = 587
# EMAIL_SUBJECT_PREFIX = ''
# EMAIL_USE_TLS = False
EOF

#Set up database
python manage.py migrate --noinput
python manage.py shell <<EOF
#Create site
from django.contrib.sites.models import Site
Site.objects.create(
    name='$SITE_NAME',
    domain='$SITE_DOMAIN',
)
#Create superuser
from django.contrib.auth import get_user_model
get_user_model().objects.create_superuser(
    username='$SUPERUSER_USERNAME',
    email='$SUPERUSER_EMAIL',
    password='$SUPERUSER_PASSWORD',
)
EOF

#Set up init script (todo)
#Set up nginx (todo)
echo "done!"
echo "here are some other optional but recommended things to install:"
echo "apt-get dist-upgrade -y"
echo "apt-get install -y sudo htop cron-apt"
