
if [ $# -eq 1 ]
then
    server=$1
else
    echo "Please use the server name or uuid as an input parameter!"
    exit 1;
fi

function get_host {
    host=$(openstack server show $server | grep hostname | awk '{print $4}')
}

function get_status {
    status=$(openstack server show $server | grep status | awk '{print $4}')
}

get_host
get_status

echo "Now Server $server is running in host: $host"
echo "$server current status is: $status"
echo -n "Migrating $server now:"
starttime=`date +'%Y-%m-%d %H:%M:%S'`
openstack server migrate $server

get_status

while [ $status != "VERIFY_RESIZE" ]
do
    echo -n "************"
    get_status
done

endtime=`date +'%Y-%m-%d %H:%M:%S'`
start_seconds=$(date --date="$starttime" +%s);
end_seconds=$(date --date="$endtime" +%s);

get_host
get_status

echo "Done!"
echo "$server has been migrated to $host already, "$((end_seconds-start_seconds))"s used."
echo "$server current status is: $status"
read -p "Type y to confirm the migration: " input
case $input in
    [yY]) 
    echo "Confirm the Migration now."
    nova resize-confirm $server
    ;;
    [nN])
    echo "Do Not confirm the Migration."
    exit 1;
    ;;
esac

get_status

if [ $status == "ACTIVE" ]
then
    echo "$server current status is: $status"
    echo "$server has been migrated to host $host successfully"
else
    echo "$server current status is: $status"
    echo "Migration failed, please check the server status manually!"
    exit 1;
fi
