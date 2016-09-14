#!/bin/bash

#Install sixthings on a new debian 8 server by running this script as root.

#Super fast deployment for testing:
# wget -O- https://raw.github.com/wizpig64/sixthings/master/deploy/debian8.sh | sh

#Not as fast deployment for production:
# wget https://raw.github.com/wizpig64/sixthings/master/deploy/debian8.sh
# vi debian8.sh #make your changes here
# cat debian8.sh | sh

#Some Notes:
# - No Channels/ASGI support yet. #TODO
# - Systemd will be made the system's init provider if it isn't already.
#   - This could easily break setups on non-new servers. Be careful.
# - Project will install to /var/www/sixthings by default.
# - Some basic, commented-off HTTPS support is included in nginx conf.
# - Setting up a database other than sqlite is up to you.
# - Gunicorn binds to a unix socket which nginx proxies to.
#   - Change this to ip:port when serving nginx and gunicorn on seperate servers.
#   - Also set the --forwarded-allow-ips flag for gunicorn.
# - Everything in "Generate local settings" and up is intended to be customized for production.


#Check for root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi


#Variables
SITE_NAME="Six Things"
SITE_DOMAIN=sixthings.example.com
SUPERUSER_USERNAME=admin
SUPERUSER_PASSWORD=change_my_password
SUPERUSER_EMAIL=admin@$SITE_DOMAIN

DEBUG=False
ALLOWED_HOSTS="['$SITE_DOMAIN', ]"
SECRET_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#$%^&*(-=+)_' | fold -w 50 | head -n 1)

PROJECT_NAME=sixthings
PROJECT_DIR=/var/www/$PROJECT_NAME
PROJECT_USER=www-data
GIT_REPO=https://github.com/wizpig64/sixthings.git


#Install system requirements
#optionally, dist-upgrade and install some suggested packages if you'd like.
apt-get update
#apt-get dist-upgrade -y
apt-get install -y \
    build-essential \
    curl \
    git \
    nginx \
    python-dev \
    sudo \
    systemd-sysv \
    virtualenv \
    # cron-apt \
    # htop \


#Download project
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR
git clone $GIT_REPO .


#Generate local settings
cat <<EOF > project/settings_local.py
#Local settings for $SITE_NAME

DEBUG=$DEBUG
SECRET_KEY='$SECRET_KEY'
ALLOWED_HOSTS=$ALLOWED_HOSTS

# SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')

# DATABASES = {
#     'default': {
#         'ENGINE': 'django.db.backends.sqlite3',
#         'NAME': os.path.join(BASE_DIR, 'db.sqlite3'),
#     }
# }

# EMAIL_HOST = '$SITE_DOMAIN'
# EMAIL_HOST_USER = '$SUPERUSER_EMAIL'
# EMAIL_HOST_PASSWORD = 'password'
# EMAIL_PORT = 587
# EMAIL_SUBJECT_PREFIX = ''
# EMAIL_USE_TLS = False
# DEFAULT_FROM_EMAIL = EMAIL_HOST_USER
# SERVER_EMAIL = EMAIL_HOST_USER
EOF


#Assign ownership of project to PROJECT_USER
chown -R www-data:www-data .


#Do the following as the PROJECT_USER (a bit messy i know)
sudo -u $PROJECT_USER bash <<ENDUSER


#Initialize project
cd $PROJECT_DIR
virtualenv .
source bin/activate
pip install -r requirements.txt


#Set up media and static directories
mkdir -p serve/media serve/static
python manage.py collectstatic -cl --noinput


#Set up database
python manage.py migrate --noinput
python manage.py shell <<EOF

#Update default site
from django.contrib.sites.models import Site
Site.objects.update(
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


#Go back to root user
ENDUSER


#Set up service and socket with systemd.
cat <<EOF > /etc/systemd/system/$PROJECT_NAME.service
[Unit]
Description=$PROJECT_NAME daemon
Requires=$PROJECT_NAME.socket
After=network.target

[Service]
PIDFile=/run/$PROJECT_NAME/pid
User=www-data
Group=www-data
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/bin/gunicorn \\
  --pid /run/$PROJECT_NAME/pid \\
  --workers 4 \\
  --reload False \\
  project.wsgi
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=/bin/kill -s TERM \$MAINPID

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > /etc/systemd/system/$PROJECT_NAME.socket
[Unit]
Description=$PROJECT_NAME socket

[Socket]
ListenStream=/run/$PROJECT_NAME/socket
ListenStream=0.0.0.0:9000
ListenStream=[::]:8000

[Install]
WantedBy=sockets.target
EOF

cat <<EOF > /usr/lib/tmpfiles.d/$PROJECT_NAME.conf
d /run/$PROJECT_NAME 0755 www-data www-data -
EOF


#Set up nginx, adding on to default config.
cat <<EOF > /etc/nginx/sites-available/$PROJECT_NAME
#Instructions for enabling HTTPS:
# - Enable the commented server that forwards HTTP to HTTPS
# - Switch the listen lines in the main server config
# - Provide SSL key and certificate files
# - Enable SECURE_PROXY_SSL_HEADER in project/settings_local.py

upstream $(echo $PROJECT_NAME)_app_server {
    # fail_timeout=0 means we always retry an upstream even if it failed
    # to return a good HTTP response
    server unix:/run/$PROJECT_NAME/socket fail_timeout=0;
    # server 0.0.0.0:9000 fail_timeout=0;
}

# server {
#     #301 all http requests to https.
#     listen                  80 default_server;
#     server_name             $SITE_DOMAIN;
#     return                  301 https://\$host\$request_uri;
# }

server {
    listen                  80 deferred;
    # listen                  443 deferred ssl;
    client_max_body_size    4G;
    server_name             $SITE_DOMAIN;
    keepalive_timeout       5;

    # ssl_certificate         /path/to/ssl.crt;
    # ssl_certificate_key     /path/to/ssl.key;

    # path for static and files
    root                    $PROJECT_DIR/serve;

    location / {
        # checks for static file, if not found proxy to app
        try_files           \$uri @proxy_to_app;
    }

    location @proxy_to_app {
        proxy_pass_header   Server;
        proxy_set_header    Host \$http_host;
        proxy_set_header    X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header    X-Forwarded-Proto \$scheme;
        proxy_set_header    X-Real-IP \$remote_addr;
        proxy_redirect      off;
        proxy_pass          http://$(echo $PROJECT_NAME)_app_server;
    }

    error_page 500 502 503 504 /500.html;
    location = /500.html {
        root                $PROJECT_DIR/serve/static/50x.html;
    }
}
EOF
ln -s /etc/nginx/sites-available/$PROJECT_NAME /etc/nginx/sites-enabled/$PROJECT_NAME


#Enable everything
systemctl daemon-reload
systemctl enable \
    nginx.service \
    $PROJECT_NAME.socket \
    $PROJECT_NAME.service
systemctl restart \
    systemd-tmpfiles-setup.service \
    nginx.service \
    $PROJECT_NAME.socket \
    $PROJECT_NAME.service
systemctl status -l \
    nginx.service \
    $PROJECT_NAME.socket \
    $PROJECT_NAME.service

#Done
echo "done! navigate to http://$SITE_DOMAIN/ to make sure it worked."
echo "If systemd wasnt the init provider before, you'll definitely need to reboot first."

