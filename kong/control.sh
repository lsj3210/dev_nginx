#!/bin/bash

start() {
    source /etc/profile
    cd /usr/local/source/kong
    make install
    /usr/local/openresty/bin/kong start
    cd /
}
 
stop() {
    source /etc/profile
    kong stop
}

reload() {
    source /etc/profile
    cd /usr/local/source/kong
    make install
    /usr/local/openresty/bin/kong start
    cd /
}

status(){
    if test $( pgrep -f nginx | wc -l ) -eq 0; then
        echo "is not running"
    else
        echo "is running"
    fi

    #count=`ps -ef |grep nginx |grep -v "grep" |wc -l`
    #if [ 0 == $count ];then
    #    echo "is not running"
    #else
    #    echo "is running"
    #fi
}
 
case $1 in
    start)
        start
        ;;
    stop)  
        stop
        ;;
    restart)
        reload
        ;;
    status)
        status
        exit $?  
        ;;
    kill)
        terminate
        ;;
    *)
        echo -e "no parameter"
        ;;
esac    
exit 0
