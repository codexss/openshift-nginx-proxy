#!/bin/bash

NGINX_VERSION='1.11.4'
PCRE_VERSION='8.39'
OPENSSL_VERSION='1.1.0a'
ZLIB_VERSION='1.2.8'

cd $OPENSHIFT_TMP_DIR

wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
tar xzf nginx-${NGINX_VERSION}.tar.gz
wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-${PCRE_VERSION}.tar.gz
tar xzf pcre-${PCRE_VERSION}.tar.gz
wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz
tar xzf openssl${OPENSSL_VERSION}.tar.gz
wget http://zlib.net/zlib-${ZLIB_VERSION}.tar.gz
tar xzf zlib-${ZLIB_VERSION}.tar.gz
git clone https://github.com/cuber/ngx_http_google_filter_module
git clone https://github.com/yaoweibin/ngx_http_substitutions_filter_module
cd ${OPENSHIFT_TMP_DIR}nginx-${NGINX_VERSION}
./configure \
  --prefix=$OPENSHIFT_DATA_DIR \
  --with-pcre=../pcre-${PCRE_VERSION} \
  --with-openssl=../openssl-${OPENSSL_VERSION} \
  --with-zlib=../zlib-${ZLIB_VERSION} \
  --with-http_ssl_module \
  --add-module=../ngx_http_google_filter_module \
  --add-module=../ngx_http_substitutions_filter_module
make -j4 && make install
rm -rf ${OPENSHIFT_TMP_DIR}
cd ${OPENSHIFT_REPO_DIR}.openshift/action_hooks
rm -rf start
cat>start<<EOF
#!/bin/bash
# The logic to start up your application should be put in this
# script. The application will work only if it binds to
# \$OPENSHIFT_DIY_IP:8080
#nohup \$OPENSHIFT_REPO_DIR/diy/testrubyserver.rb \$OPENSHIFT_DIY_IP \$OPENSHIFT_REPO_DIR/diy |& /usr/bin/logshifter -tag diy &
sed -e "s/`echo '$OPENSHIFT_IP:$OPENSHIFT_PORT'`/`echo $OPENSHIFT_DIY_IP:$OPENSHIFT_DIY_PORT`/;s/8.8.8.8/`cat /etc/resolv.conf |grep -i nameserver|head -n1|cut -d ' ' -f2`/" $OPENSHIFT_DATA_DIR/conf/nginx.conf.template > $OPENSHIFT_DATA_DIR/conf/nginx.conf
nohup $OPENSHIFT_DATA_DIR/sbin/nginx > $OPENSHIFT_DIY_LOG_DIR/server.log 2>&1 &
EOF
chmod 755 start
rm -rf stop
cat>stop<<EOF
#!/bin/bash
source $OPENSHIFT_CARTRIDGE_SDK_BASH

# The logic to stop your application should be put in this script.
if [ -z "$(ps -ef | grep nginx | grep -v grep)" ]
then
    client_result "Application is already stopped"
else
    kill `ps -ef | grep nginx | grep -v grep | awk '{ print $2 }'` > /dev/null 2>&1
fi
EOF
chmod 755 stop

cd $OPENSHIFT_DATA_DIR/conf
rm nginx.conf
wget --no-check-certificate https://github.com/codexss/openshift-nginx-proxy/raw/master/nginx.conf
sed -i "s/OPENSHIFT_DIY_IP/$OPENSHIFT_DIY_IP/g" nginx.conf
sed -i "s/xxx-xxx.rhcloud.com/$OPENSHIFT_APP_DNS/g" nginx.conf
gear stop
gear start
