#!/bin/bash

TO_ERASE=$1
LOCK_FILE=$2

IS_ENABLED="FALSE"

IS_RUNNING="FALSE"

CMD_CHECK_DOMAIN="virsh list"

echo "Prepare to delete environment ${TO_ERASE}..."

if [ -z "$1" ]

    then

        echo "Use it `basename $0` ENVNAME"

    exit 1

    fi



[ $(virsh list --all|awk '{print $2}'|grep -c "^${TO_ERASE}$") -eq 1 ] &&  echo "domain enabled" && IS_ENABLED="TRUE"

[ $(virsh list|awk '{print $2}'|grep -c "^${TO_ERASE}$") -eq 1 ]  && echo "domain is running now" && IS_RUNNING="TRUE"

if [ $(virsh list --all|grep -c "${TO_ERASE}") -gt 0 -a ${IS_ENABLED} == "FALSE" ]

    then

        lava=`virsh list --all|grep  "${BUILD_USER_ID}"|awk '{print $2}'`

        echo "Too many domains has been matched!"

        echo "Please take a look:"

        echo "${lava}"

        echo "Please choose one of them and run this job again!"

        exit 1

fi



if [ ${IS_ENABLED} == "FALSE" ]

    then

        echo "Domain not found..."

        exit 1

    else

        echo "operation is successfull"

        [ ${IS_RUNNING} == "TRUE" ] && virsh destroy ${TO_ERASE} && echo "domain shutting down now" && sleep 5 && [ $(virsh list|grep -c "^${TO_ERASE}$") -eq 0 ] && echo Domain ${TO_ERASE} is stopped now

        virsh undefine --remove-all-storage --snapshots-metadata --managed-save `virsh domuuid ${TO_ERASE}` && sleep 3 && echo "Operation is successfull, domain has been deleted!"

        # Clean resources
        sed -i "/${TO_ERASE}/d" $LOCK_FILE

        exit 0

fi
