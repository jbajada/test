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

        --puppetserver=*)
            vPuppetServer="${i#*=}"
        ;;
        
        --resourcegroup=*)
            vResourceGroup="${i#*=}"
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
        exit 1
      fi
    ;;
  *)
    ECHO 'OS Not Supported'
    exit 1 
    ;;
esac

## Install Required Files
yum install -y ntp

## Disable all existing Repos
#for f in /etc/yum.repos.d/*.repo; do mv "$f" "$f.disabled"; done
#yum clean all

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

## Add OS repo
cat > /etc/yum.repos.d/hndg-${DistroBasedOn}-base.repo <<EOF
[hndg-${DistroBasedOn}-base]
name=${DistroBasedOn} Repository
baseurl=http://${DistroBasedOn}-base.${DistroBasedOn}${MajorRev}.repo.dev.hndigital.net
enabled=1
gpgcheck=0
EOF

## Install Puppet
yum install -y puppet

## Disable all existing Repos
for f in /etc/yum.repos.d/*.repo; do mv "$f" "$f.disabled"; done
yum clean all

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

## Add OS repo
cat > /etc/yum.repos.d/hndg-${DistroBasedOn}-base.repo <<EOF
[hndg-${DistroBasedOn}-base]
name=${DistroBasedOn} Repository
baseurl=http://${DistroBasedOn}-base.${DistroBasedOn}${MajorRev}.repo.dev.hndigital.net
enabled=1
gpgcheck=0
EOF


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

## Configure puppet to use the correct certificates
export ssldir=$(puppet agent --genconfig | grep -e 'ssldir =' | sed -e 's/^[ \t]*//' | awk '{print $3}')
puppet cert list --all
mkdir -p $ssldir/certs/
mkdir -p $ssldir/public_keys/
mkdir -p $ssldir/private_keys/
## Permanent Certificate Solution
##curl -u ${envGitUsername}:${envGitPassword} ${vGitRepository}/securitykeys/browse/puppet/certs/ca.pem?raw -o $ssldir/certs/ca.pem
##curl -u ${envGitUsername}:${envGitPassword} ${vGitRepository}/securitykeys/browse/puppet/ca/signed/${vEnvironmentType}.hndigital.net.pem?raw -o $ssldir/certs/${vEnvironmentType}.hndigital.net.pem
##curl -u ${envGitUsername}:${envGitPassword} ${vGitRepository}/securitykeys/browse/puppet/public_keys/${vEnvironmentType}.hndigital.net.pem?raw -o $ssldir/public_keys/${vEnvironmentType}.hndigital.net.pem
##curl -u ${envGitUsername}:${envGitPassword} ${vGitRepository}/securitykeys/browse/puppet/private_keys/${vEnvironmentType}.hndigital.net.pem?raw -o $ssldir/private_keys/${vEnvironmentType}.hndigital.net.pem
## Temporary Certificate Solution
curl ${vGitRepository}/ssl/certs/ca.pem -o $ssldir/certs/ca.pem
curl ${vGitRepository}/ssl/certs/${vEnvironmentType}.hndigital.net.pem -o $ssldir/certs/${vEnvironmentType}.hndigital.net.pem
curl ${vGitRepository}/ssl/public_keys/${vEnvironmentType}.hndigital.net.pem -o $ssldir/public_keys/${vEnvironmentType}.hndigital.net.pem
curl ${vGitRepository}/ssl/private_keys/${vEnvironmentType}.hndigital.net.pem -o $ssldir/private_keys/${vEnvironmentType}.hndigital.net.pem
find $ssldir/ -name '*.pem' | xargs chmod 600
find $ssldir/ -name '*.pem' | xargs chown puppet:puppet

## Configure puppet
puppet config set --section agent pluginsync true
puppet config set --section agent server ${vPuppetServer}
puppet config set --section agent certname ${vEnvironmentType}.hndigital.net
#puppet config set --section agent certname ${vInstance_id}
puppet config set --section agent node_name facter
puppet config set --section agent node_name_fact fqdn

# Create Factor Facts folder
mkdir -p /etc/facter/facts.d

# Configure Environment Facts
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

# Configure Server Facts
cat > /etc/facter/facts.d/server.txt <<EOF
srv_name=${vServerName}
srv_type=${vServerType}
srv_instance=${vServerInstance}
EOF

# Remove sensitive data from log files
find /var/log/${vInfrastructure} -type f -name '*.log' -exec sed -i -r 's:--gitpassword=\\*"([^"]*)\\*":--gitpassword="******":g' {} \;

# Setup Puppet cron and Run Puppet","\n",
puppet resource cron puppet-agent ensure=present user=root minute=*/15 command='/usr/bin/puppet agent --onetime --no-daemonize --splay'
grep -q -F 'puppet agent --test' /etc/rc.local || echo 'puppet agent --test' >> /etc/rc.local
nohup puppet agent --test &