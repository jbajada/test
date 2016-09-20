#!/bin/bash

## Read in arguments
for i in "$@"
do
    case $i in
        --environmentplatform=*)
            vEnvironmentPlatform="${i#*=}"
        ;;

        --environmentlocation=*)
            vEnvironmentLocation="${i#*=}"
        ;;
        
        --environmentname=*)
            vEnvironmentName="${i#*=}"
        ;;

        --environmentbrand=*)
            vEnvironmentBrand="${i#*=}"
        ;;

        --environmentdescription=*)
            vEnvironmentDescription="${i#*=}"
        ;;

        --environmenttype=*)
            vEnvironmentType="${i#*=}"
        ;;

        --environmentinstance=*)
            vEnvironmentInstance="${i#*=}"
        ;;

        --environmentowner=*)
            vEnvironmentOwner="${i#*=}"
        ;;

        --servername=*)
            vServerName="${i#*=}"
        ;;

        --servertype=*)
            vServerType="${i#*=}"
        ;;

        --serverinstance=*)
            vServerInstance="${i#*=}"
        ;;

        --gitrepository=*)
            vGitRepository="${i#*=}"
        ;;

        --gitusername=*)
            vGitUsername="${i#*=}"
        ;;

        --gitpassword=*)
            vGitPassword="${i#*=}"
        ;;
       
        --resourcegroup=*)
            vResourceGroup="${i#*=}"
        ;;
        
        --puppetdbpassword=*)
        	vPuppetDbPassword="${i#*=}"
        ;;
        
        --storageaccountname=*)
            vStorageAccountName="${i#*=}"
        ;;

        --primarydns=*)
            vPrimaryDNS="${i#*=}"
        ;;

        --secondarydns=*)
            vSecondaryDNS="${i#*=}"
        ;;
        
        *)
            # unknown option
        ;;
    esac
done

## Get Server Machine Details
OS=$(uname)
KERNEL=$(uname -r)
MACH=$(uname -m)

## Get OS Details
case $OS in
  'Linux')
      if [ -f /etc/redhat-release ]; then
        DistroBasedOn='redhat'
        DIST=$(cat /etc/redhat-release |sed s/\ release.*//)
        PSUEDONAME=$(cat /etc/redhat-release | sed s/.*\(// | sed s/\)//)
        REV=$(cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//)
        MajorRev=$(cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*// | sed 's/[.].*//')
      fi
      if [ -f /etc/centos-release ]; then
        DistroBasedOn='centos'
        DIST=$(cat /etc/centos-release |sed s/\ release.*//)
        PSUEDONAME=$(cat /etc/centos-release | sed s/.*\(// | sed s/\)//)
        REV=$(cat /etc/centos-release | sed s/.*release\ // | sed s/\ .*//)
        MajorRev=$(cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*// | sed 's/[.].*//')
      fi
      if [ -f /etc/UnitedLinux-release ] ; then
        ECHO 'OS Not Supported'
        exit 2
      fi
    ;;
  *)
    ECHO 'OS Not Supported'
    exit 2 
    ;;
esac

## Get unique ID of current server
if [ -f /sys/hypervisor/uuid ] && [ `head -c 3 /sys/hypervisor/uuid` == ec2 ]; then
  ## Running under AWS
  vInstance_id=$(wget -q -O - http://instance-data/latest/meta-data/instance-id)
  vInfrastructure="aws"
else
  ## Running under Azure  
  vInstance_id=$(dmidecode | grep UUID | awk '{ print $2}')
  vInfrastructure="azure"
fi

## Install Required Packages
yum install -y ntp

## Function: Scan for New Data Disks
scan_for_new_disks() {
    # Looks for unpartitioned disks
    declare -a RET
    DEVS=($(ls -1 /dev/sd* | egrep -v "/dev/sda|/dev/sdb" | egrep -v "[0-9]$"))
    for DEV in "${DEVS[@]}";
    do
        # Check each device if there is a "1" partition. If not, "assume" it is not partitioned.
        if [ ! -b ${DEV}1 ];
        then
            RET+="${DEV} "
        fi
    done
    echo "${RET}"
}

## Function: Check to see if disk is partitioned
is_partitioned() {
# Checks if there is a valid partition table on the
# specified disk
    OUTPUT=$(sfdisk -l ${1} 2>&1)
    grep "No partitions found" "${OUTPUT}" >/dev/null 2>&1
    return "${?}"       
}

## Function: Check to see if disk has a partition
has_filesystem() {
    DEVICE=${1}
    OUTPUT=$(file -L -s ${DEVICE})
    grep filesystem <<< "${OUTPUT}" > /dev/null 2>&1
    return ${?}
}

## Function: Partition disk
do_partition() {
# Creates one primary partition on the disk, using all available space
    DISK=${1}
    echo "n
p
1


w"| fdisk "${DISK}" > /dev/null 2>&1

#
# Use the bash-specific $PIPESTATUS to ensure we get the correct exit code
# from fdisk and not from echo
if [ ${PIPESTATUS[1]} -ne 0 ];
then
    echo "An error occurred partitioning ${DISK}" >&2
    exit 2
fi
}

## Partition and format all new data disks
DISKS=($(scan_for_new_disks))
for DISK in "${DISKS[@]}";
do
    is_partitioned ${DISK}
    if [ ${?} -ne 0 ];
    then
        # Disk not partitioned, so partition it now
        do_partition ${DISK}
    fi
    PARTITION=$(fdisk -l ${DISK}|grep -A 1 Device|tail -n 1|awk '{print $1}')
    has_filesystem ${PARTITION}
    if [ ${?} -ne 0 ];
    then   
        ## Creating filesystem
        LABEL=$(fdisk -l /dev/sdc1 |grep "Disk /dev/sdc1:" | head -n 2 | tail -n 1 | cut -d " " -f 5 | awk '{if (($1/1000000000) > 200) print "repo"; else print "puppet" }')
        mkfs -j -t xfs -L ${LABEL} ${PARTITION}
    fi
done

## Mount Volumes
mkdir -p /var/www/repo
mount -l repo /var/www/repo
mkdir -p /etc/puppet
mount -l puppet /etc/puppet
mkdir -p /var/lib/puppet/reports

## Add PuppetLabs Products repo
cat > /etc/yum.repos.d/hndg-puppetlabs.repo <<EOF
[hndg-puppetlabs-products]
name=Puppet Labs Products
baseurl=http://puppetlabs-products.${DistroBasedOn}${MajorRev}.repo.dev.hndigital.net
enabled=1
gpgcheck=0

[hndg-puppetlabs-deps]
name=Puppet Labs Dependencies
baseurl=http://puppetlabs-deps.${DistroBasedOn}${MajorRev}.repo.dev.hndigital.net
enabled=1
gpgcheck=0
EOF

## Setup DNS Settings
sed -i 's/nameserver.*/nameserver ${vPrimaryDNS}\nnameserver ${vSecondaryDNS}/g' /etc/resolv.conf 

## Install Required Packages
yum install -y createrepo httpd git

## Download Repo Files
git clone https://${vGitUsername}:${vGitPassword}@stash.harveynorman.com.au/scm/puppet/yumrepo.git /var/www/repo/hndigital
git clone https://${vGitUsername}:${vGitPassword}@stash.harveynorman.com.au/scm/puppet/yumrepo-puppet.git /var/www/repo/puppet

## Configure Repos
sed -i "s/Listen 80/Listen 80\nListen 8181/g" /etc/httpd/conf/httpd.conf
cat > /etc/httpd/conf.d/reposerver.conf
NameVirtualHost *:80

<VirtualHost *:80>
    ServerName reposerver.au.hndigital.net
    ServerAlias *.repo.dev.hndigital.net
    ServerAlias *.repo.au.hndigital.net
    VirtualDocumentRoot /var/www/repo/%2/%1
    ErrorLog logs/reposerver-error_log
    CustomLog logs/reposerver-access_log common
    <Directory /var/www/repo/%2/%1>
        AllowOverride None
        Options +Indexes
    </Directory>   
</VirtualHost>
EOF

## Refresh Repos
createrepo -v /var/www/repo && /sbin/service httpd restart

## Perform a yum clean
yum clean all

## Install PostgreSQL
yum install -y postgresql9-server

## Setup PostgreSQL
service postgresql initdb
sed -i "s/^local.*peer$//g" /var/lib/pgsql9/data/pg_hba.conf
sed -i "s/^host.*ident$//g" /var/lib/pgsql9/data/pg_hba.conf
echo "" >> /var/lib/pgsql9/data/pg_hba.conf
echo "local    all    all                    trust" >> /var/lib/pgsql9/data/pg_hba.conf
echo "host     all    all    127.0.0.1/32    trust" >> /var/lib/pgsql9/data/pg_hba.conf
/sbin/service postgresql start
su - postgres -c "echo \"CREATE ROLE puppetdb WITH NOSUPERUSER NOCREATEDB NOCREATEROLE LOGIN PASSWORD '${vPuppetDbPassword}';\" | psql -U postgres"
su - postgres -c "createdb -O puppetdb puppetdb"

## Install Puppet
yum install -y puppet

## Install Puppet DB
yum install -y puppetdb puppetdb-terminus

## Install RubyGems & Hiera-eyaml
yum install -y rubygems
gem install hiera-eyaml

## Setup PuppetDB
cat > /etc/puppetdb/conf.d/database.ini
[database]
classname = org.postgresql.Driver
subprotocol = postgresql
subname = //127.0.0.1:5432/puppetdb
username = puppetdb
password = ${vPuppetDbPassword}
log-slow-statements = 10
EOF

## Configure PuppetDB conf file
sed -i "s/^# host = <host>/host = 0.0.0.0/g" /etc/puppetdb/conf.d/jetty.ini
sed -i "s/^ssl-host =.*$/ssl-host = 0.0.0.0/g" /etc/puppetdb/conf.d/jetty.ini

## Generate Puppet Certs
hostname puppet
hostname -f puppet.${vEnvironmentType}.hndigital.cloud
fqdn=$(hostname --fqdn)
puppet cert generate ${fqdn}

## Configure Environment Facts
cat > /etc/facter/facts.d/environment.txt <<EOF
env_platform=${vEnvironmentPlatform}
env_location=${vEnvironmentLocation}
env_name=${vEnvironmentName}
env_description=${vEnvironmentDescription}
env_brand=${vEnvironmentBrand}
env_type=${vEnvironmentType}
env_instance=${vEnvironmentInstance}
env_owner=${vEnvironmentOwner}
env_resourcegroup=${vResourceGroup}
env_storageaccountname=${vStorageAccountName}
env_${vInfrastructure}_private_ns1_name=${vPrimaryDNS}
env_${vInfrastructure}_private_ns2_name=${vSecondaryDNS}
EOF

## Configure Server Facts
cat > /etc/facter/facts.d/server.txt <<EOF
srv_name=${vServerName}
srv_type=${vServerType}
srv_instance=${vServerInstance}
EOF

## Download Puppet Master modules from Stash
rm -rf /etc/puppet/*
git clone https://${vGitUsername}:${vGitPassword}@stash.harveynorman.com.au/scm/puppet/puppet.git /etc/puppet &&
mkdir -p /etc/puppet/reports
mkdir -p /etc/puppet/secure/keys
ln -s /etc/puppet/reports /var/lib/puppet/reports
curl -u ${vGitUsername}:${vGitPassword} 'https://stash.harveynorman.com.au/projects/PUPPET/repos/securitykeys/browse/eYaml/{private,public}_key.pkcs7.pem?raw' -o /etc/puppet/secure/keys/#1_key.pkcs7.pem
export ssldir=$(puppet agent --genconfig | grep -e 'ssldir =' | sed -e 's/^[ \t]*//' | awk '{print $3}')
git clone 'https://${vGitUsername}:${vGitPassword}@stash.harveynorman.com.au/scm/puppet/securitykeys.git' /tmp/puppetkeys &&
rm -rf $ssldir && mkdir -p $ssldir
mv /tmp/puppetkeys/puppet/* $ssldir
rm -rf /etc/puppetdb/ssl && mkdir -p /etc/puppetdb/ssl
mv /tmp/puppetkeys/puppetdb/* /etc/puppetdb/ssl
rm -rf /tmp/puppetkeys/
chown -R puppet:puppet -R /etc/puppet/secure
chown -R puppet:puppet -R $ssldir/
chown -R puppetdb:puppetdb -R /etc/puppetdb/ssl/
find /var/lib/puppet/ssl/ /etc/puppetdb /etc/puppet -name '*.pem' | xargs chmod 600

## Start PuppetDB
service puppetdb restart

## Wait for Puppet DB to start
sleep 60

## Start Puppet Master and then configure it
puppet master --verbose




## Configure puppet to use the correct certificates
#export ssldir=$(puppet agent --genconfig | grep -e 'ssldir =' | sed -e 's/^[ \t]*//' | awk '{print $3}')
#puppet cert list --all
#mkdir -p $ssldir/certs/
#mkdir -p $ssldir/public_keys/
#mkdir -p $ssldir/private_keys/
#curl -u ${vGitUsername}:${vGitPassword} ${vGitRepository}/ssl/certs/ca.pem?raw -o $ssldir/certs/ca.pem
#curl -u ${vGitUsername}:${vGitPassword} ${vGitRepository}/ssl/certs/${vEnvironmentType}.hndigital.net.pem?raw -o $ssldir/certs/${vEnvironmentType}.hndigital.net.pem
#curl -u ${vGitUsername}:${vGitPassword} ${vGitRepository}/ssl/public_keys/${vEnvironmentType}.hndigital.net.pem?raw -o $ssldir/public_keys/${vEnvironmentType}.hndigital.net.pem
#curl -u ${vGitUsername}:${vGitPassword} ${vGitRepository}/ssl/private_keys/${vEnvironmentType}.hndigital.net.pem?raw -o $ssldir/private_keys/${vEnvironmentType}.hndigital.net.pem
#find $ssldir/ -name '*.pem' | xargs chmod 600
#find $ssldir/ -name '*.pem' | xargs chown puppet:puppet




### Configure puppet
#puppet config set --section agent pluginsync true
#puppet config set --section agent certname ${vEnvironmentType}.hndigital.net
#puppet config set --section agent certname ${vInstance_id}
#puppet config set --section agent node_name facter
#puppet config set --section agent node_name_fact fqdn

# Create Factor Facts folder
#mkdir -p /etc/facter/facts.d



# Remove sensitive data from log files
#find /var/log/${vInfrastructure} -type f -name '*.log' -exec sed -i -r 's:--gitpassword=\\*"([^"]*)\\*":--gitpassword="******":g' {} \;

# Setup Puppet cron and Run Puppet","\n",
##puppet resource cron puppet-agent ensure=present user=root minute=*/15 command='/usr/bin/puppet agent --onetime --no-daemonize --splay'
##grep -q -F 'puppet agent --test' /etc/rc.local || echo 'puppet agent --test' >> /etc/rc.local
#nohup puppet agent --test &