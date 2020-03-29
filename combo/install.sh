#1 unzip soft package
cd soft/
sudo tar -xvf pcre-8.42.tar.gz
sudo tar -xvf zlib-1.2.11.tar.gz
sudo tar -xvf openssl-1.1.0i.tar.gz 
sudo tar -xvf openresty-1.13.6.2.tar.gz
#sudo tar -xvf luarocks-2.4.3.tar.gz
 
#2 add user
useradd -s /sbin/nologin -M nginx

#3 install openresty 
cd openresty-1.13.6.2/ && ./configure --with-pcre=../pcre-8.42 --with-zlib=../zlib-1.2.11 --with-openssl=../openssl-1.1.0i && gmake && gmake install
ln -s /usr/local/openresty/nginx/ /usr/local/nginx
mkdir /data/nginx && mkdir /data/nginx/logs
cd ../

#4 install luarocks
#cd luarocks-2.4.3 &&  ./configure --prefix=/usr/local/luarocks-2.4.3 --lua-suffix=jit --with-lua=/usr/local/openresty/luajit --with-lua-include=/usr/local/openresty/luajit/include/luajit-2.1 
#make build -j4 && make install

#echo "#luarocks path">>/etc/profile
#echo "export PATH=\$PATH:/usr/local/luarocks-2.4.3/bin">>/etc/profile
#echo "export LUA_PATH=\"/usr/local/luarocks-2.4.3/share/lua/5.1/?.lua;/usr/local/luarocks-2.4.3/share/lua/5.1/?/init.lua;?.lua;;\"" >> /etc/profile
#echo "export LUA_CPATH=\"/usr/local/luarocks-2.4.3/lib/lua/5.1/?.so;?.so;;\"" >> /etc/profile
#source /etc/profile
 
#4 copy src
cp -rf src/* /usr/local/openresty/nginx/conf 

#5 编译iconv.so
#gcc -O2 -fPIC -I/usr/include/lua5.1 -c luaiconv.c -o luaiconv.o -I/usr/local/openresty/luajit/include/luajit-2.1
#gcc -shared -o iconv.so -L/usr/local/lib luaiconv.o -L/usr/lib -L /usr/local/openresty/luajit/
