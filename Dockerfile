FROM alpine:3.3
LABEL maintainer="Stanislaus Madueke <stan.madueke@gmail.com>"

ENV NGINX_VERSION 1.13.6
ENV NGINX_RTMP_VERSION 1.2.0
ENV NGINX_LUA_VERSION 0.10.11
ENV FFMPEG_VERSION 3.3.4
ENV LUA_JIT_VERSION 2.1.0-beta3
ENV NDK_VERSION 0.3.0

EXPOSE 1935
EXPOSE 8080

RUN mkdir -p /opt/data && mkdir /www

RUN	apk update && apk add	\
  gcc	binutils-libs binutils build-base	libgcc make pkgconf pkgconfig \
  openssl openssl-dev ca-certificates pcre \
  musl-dev libc-dev pcre-dev zlib-dev

# Get nginx source.
RUN cd /tmp && wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
  && tar zxf nginx-${NGINX_VERSION}.tar.gz \
  && rm nginx-${NGINX_VERSION}.tar.gz

# Get nginx-rtmp module.
RUN cd /tmp && wget https://github.com/arut/nginx-rtmp-module/archive/v${NGINX_RTMP_VERSION}.tar.gz \
  && tar zxf v${NGINX_RTMP_VERSION}.tar.gz && rm v${NGINX_RTMP_VERSION}.tar.gz

# Get and install LuaJIT.
RUN cd /tmp && wget http://luajit.org/download/LuaJIT-${LUA_JIT_VERSION}.tar.gz \
  && tar zxf LuaJIT-${LUA_JIT_VERSION}.tar.gz && rm LuaJIT-${LUA_JIT_VERSION}.tar.gz \
  && cd /tmp/LuaJIT-${LUA_JIT_VERSION} \
  && make PREFIX=/opt/luajit \
  && make install PREFIX=/opt/luajit

# Get nginx_devel_kit.
RUN cd /tmp && wget https://github.com/simpl/ngx_devel_kit/archive/v${NDK_VERSION}.tar.gz \
  && tar zxf v${NDK_VERSION}.tar.gz && rm v${NDK_VERSION}.tar.gz

# Get Openresty's lua_nginx module.
RUN cd /tmp && wget https://github.com/openresty/lua-nginx-module/archive/v${NGINX_LUA_VERSION}.tar.gz \
  && tar zxf v${NGINX_LUA_VERSION}.tar.gz && rm v${NGINX_LUA_VERSION}.tar.gz

# Compile nginx with nginx-rtmp and lua-nginx modules.
RUN export LUAJIT_LIB=/opt/luajit/lib \
  && export LUAJIT_INC=/opt/luajit/include/luajit-2.1 \
  && cd /tmp/nginx-${NGINX_VERSION} \
  && ./configure --with-ld-opt="-Wl,-rpath,$LUAJIT_LIB" \
  --prefix=/opt/nginx \
  --add-module=/tmp/nginx-rtmp-module-${NGINX_RTMP_VERSION} \
  --add-module=/tmp/ngx_devel_kit-${NDK_VERSION} \
  --add-module=/tmp/lua-nginx-module-${NGINX_LUA_VERSION} \
  --conf-path=/opt/nginx/nginx.conf \
  --error-log-path=/opt/nginx/logs/error.log \
  --http-log-path=/opt/nginx/logs/access.log \
  --without-http_auth_basic_module \
  --without-http_autoindex_module \
  --without-http_browser_module \
  --without-http_empty_gif_module \
  --without-http_fastcgi_module \
  --without-http_proxy_module \
  --without-http_scgi_module \
  --without-http_ssi_module \
  --without-http_uwsgi_module \
  --with-debug \
  --with-http_secure_link_module \
  && make && make install

# ffmpeg dependencies.
RUN apk add --update nasm yasm-dev lame-dev libogg-dev x264-dev libvpx-dev libvorbis-dev x265-dev freetype-dev libass-dev libwebp-dev rtmpdump-dev libtheora-dev opus-dev
RUN echo http://dl-cdn.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories
RUN apk add --update fdk-aac-dev

# Get ffmpeg source.
RUN cd /tmp/ && wget http://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz \
  && tar zxf ffmpeg-${FFMPEG_VERSION}.tar.gz && rm ffmpeg-${FFMPEG_VERSION}.tar.gz

# Compile ffmpeg.
RUN cd /tmp/ffmpeg-${FFMPEG_VERSION} && \
  ./configure \
  --enable-version3 \
  --enable-gpl \
  --enable-nonfree \
  --enable-small \
  --enable-libmp3lame \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libvpx \
  --enable-libtheora \
  --enable-libvorbis \
  --enable-libopus \
  --enable-libfdk-aac \
  --enable-libass \
  --enable-libwebp \
  --enable-librtmp \
  --enable-postproc \
  --enable-avresample \
  --enable-libfreetype \
  --enable-openssl \
  --disable-debug \
  && make && make install && make distclean

# Cleanup.
RUN rm -rf /var/cache/* /tmp/*

ADD nginx.conf /opt/nginx/nginx.conf
ADD static /www/static

CMD ["/opt/nginx/sbin/nginx"]
