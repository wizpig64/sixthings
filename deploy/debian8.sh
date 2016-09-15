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
# - In all likelyhood, a reboot will be required for the site to work.


#Check for root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi


# VARIABLES
#===========

SITE_NAME="Six Things"
SITE_DOMAIN=sixthings.agrimgt.com
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


# INSTALL SYSTEM REQUIREMENTS
#=============================

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


# INSTALL PROJECT
#=================

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
chown -R $PROJECT_USER:$PROJECT_USER .

#Initialize project
sudo -u $PROJECT_USER virtualenv .

#Install python plugins (pip updated so pip-sync works)
sudo -u $PROJECT_USER bin/pip install --upgrade pip
sudo -u $PROJECT_USER bin/pip install -r requirements.txt

#Set up static files
sudo -u $PROJECT_USER bin/python manage.py collectstatic -cl --noinput

#Set up database
sudo -u $PROJECT_USER bin/python manage.py migrate --noinput

#Update default site
sudo -u $PROJECT_USER bin/python manage.py shell <<EOF
from django.contrib.sites.models import Site
Site.objects.update(
   name='$SITE_NAME',
   domain='$SITE_DOMAIN',
)
EOF

#Create superuser
sudo -u $PROJECT_USER bin/python manage.py shell <<EOF
from django.contrib.auth import get_user_model
get_user_model().objects.create_superuser(
    username='$SUPERUSER_USERNAME',
    email='$SUPERUSER_EMAIL',
    password='$SUPERUSER_PASSWORD',
)
EOF


# SYSTEMD SCRIPTS
#=================

#Service
cat <<EOF > /etc/systemd/system/$PROJECT_NAME.service
[Unit]
Description=$PROJECT_NAME daemon
Requires=$PROJECT_NAME.socket
After=network.target

[Service]
PIDFile=/run/$PROJECT_NAME/pid
User=$PROJECT_USER
Group=$PROJECT_USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/bin/gunicorn \\
  --pid /run/$PROJECT_NAME/pid \\
  --workers 4 \\
  project.wsgi
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=/bin/kill -s TERM \$MAINPID

[Install]
WantedBy=multi-user.target
EOF

#Socket
cat <<EOF > /etc/systemd/system/$PROJECT_NAME.socket
[Unit]
Description=$PROJECT_NAME socket

[Socket]
ListenStream=/run/$PROJECT_NAME/socket
#ListenStream=0.0.0.0:8000

[Install]
WantedBy=sockets.target
EOF

#Temp files
cat <<EOF > /usr/lib/tmpfiles.d/$PROJECT_NAME.conf
d /run/$PROJECT_NAME 0755 $PROJECT_USER $PROJECT_USER -
EOF

#Enable everything
systemctl enable $PROJECT_NAME.socket
systemctl enable $PROJECT_NAME.service


# NGINX SERVER
#==============

#Set up nginx, adding on to default config.
cat <<EOF > /etc/nginx/sites-available/$PROJECT_NAME
#Instructions for enabling HTTPS:
# - Enable the commented server that forwards HTTP to HTTPS
# - Switch the listen lines in the main server config
# - Provide SSL key and certificate files
# - Enable SECURE_PROXY_SSL_HEADER in project/settings_local.py

upstream ${PROJECT_NAME}_app_server {
    # fail_timeout=0 means we always retry an upstream even if it failed
    # to return a good HTTP response
    server unix:/run/$PROJECT_NAME/socket fail_timeout=0;
    # server 0.0.0.0:8000 fail_timeout=0;
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
        proxy_pass          http://${PROJECT_NAME}_app_server;
    }

    error_page 500 502 503 504 /500.html;
    location = /500.html {
        root                $PROJECT_DIR/serve/static/50x.html;
    }
}
EOF
ln -s /etc/nginx/sites-available/$PROJECT_NAME /etc/nginx/sites-enabled/$PROJECT_NAME

#Enable nginx
systemctl enable nginx.service


# FINAL STEPS
#=============

#Create update script
cat <<EOF > $PROJECT_DIR/bin/update
#!/bin/bash

#TODO: idea, have systemd run this??
#What this script does:
# - Pull $PROJECT_NAME project changes via git.
#   - Any existing changes are stashed.
#   - Any existing commits that are lost can be found with git reflog.
# - Run some management commands.
# - Restart gunicorn.

#Check for root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

PROJECT_DIR=$PROJECT_DIR
PROJECT_NAME=$PROJECT_NAME
PROJECT_USER=$PROJECT_USER

cd \$PROJECT_DIR

#Git
sudo -u \$PROJECT_USER git fetch
sudo -u \$PROJECT_USER git stash
sudo -u \$PROJECT_USER git reset --hard origin
# sudo -u \$PROJECT_USER git submodule update --init --recursive

#Management
sudo -u \$PROJECT_USER bin/pip-sync
sudo -u \$PROJECT_USER bin/python manage.py migrate --noinput
sudo -u \$PROJECT_USER bin/python manage.py collectstatic -cl --noinput

#Gunicorn
systemctl stop \$PROJECT_NAME.service
systemctl start \$PROJECT_NAME.service
systemctl status -l \$PROJECT_NAME.service
EOF
chmod +x $PROJECT_DIR/update

#Finished
echo "Done! After rebooting, navigate to http://$SITE_DOMAIN/. Or, check status by running:"
echo "systemctl status -l \\"
echo "    nginx.service \\"
echo "    $PROJECT_NAME.socket \\"
echo "    $PROJECT_NAME.service"
echo "The project can be updated by running $PROJECT_DIR/bin/update as root."
