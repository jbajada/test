#!/bin/bash

## Read in arguments
for i in "$@"
do
    case $i in
        -w=*|--environmentplatform=*)
            vEnvironmentPlatform="${i#*=}"
        ;;

        -l=*|--environmentlocation=*)
            vEnvironmentLocation="${i#*=}"
        ;;
        
        -e=*|--environmentname=*)
            vEnvironmentName="${i#*=}"
        ;;

        -b=*|--environmentbrand=*)
            vEnvironmentBrand="${i#*=}"
        ;;

        -d=*|--environmentdescription=*)
            vEnvironmentDescription="${i#*=}"
        ;;

        -t=*|--environmenttype=*)
            vEnvironmentType="${i#*=}"
        ;;

        -i=*|--environmentinstance=*)
            vEnvironmentInstance="${i#*=}"
        ;;

        -o=*|--environmentowner=*)
            vEnvironmentOwner="${i#*=}"
        ;;

        -n=*|--servername=*)
            vServerName="${i#*=}"
        ;;

        -s=*|--servertype=*)
            vServerType="${i#*=}"
        ;;

        -c=*|--serverinstance=*)
            vServerInstance="${i#*=}"
        ;;

        -r=*|--gitrepository=*)
            vGitRepository="${i#*=}"
        ;;

        -u=*|--gitusername=*)
            vGitUsername="${i#*=}"
        ;;

        -p=*|--gitpassword=*)
            vGitPassword="${i#*=}"
        ;;

        -m=*|--puppetserver=*)
            vPuppetServer="${i#*=}"
        ;;
        
        -g=*|--resourcegroup=*)
            vResourceGroup="${i#*=}"
        ;;
        
        -a=*|--storageaccountname=*)
            vStorageAccountName="${i#*=}"
        ;;
        
        *)
            # unknown option
        ;;
    esac
done

## Disable all Repos
sed -i 's/enabled=1/enabled=0/g' /etc/yum.repos.d/*.repo
sed -i 's/^releasever=latest/#releasever=latest/g' /etc/yum.conf

## Add PuppetLabs Products repo
cat > /etc/yum.repos.d/puppetlabs.repo <<EOF
[puppetlabs-products]
name=Puppet Labs Products
baseurl=http://puppetlabs-products.repo.dev.hndigital.net
enabled=1
gpgcheck=0

[puppetlabs-deps]
name=Puppet Labs Dependencies
baseurl=http://puppetlabs-deps.repo.dev.hndigital.net
enabled=1
gpgcheck=0
EOF

## Install Puppet
yum install -y puppet-3.4.3

## Install Puppet Certificates
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

## Configure Puppet
cat > /etc/puppet/puppet.conf <<EOF
[main]
    # The Puppet log directory.
    # The default value is '/log'.
    logdir = /var/log/puppet

    # Where Puppet PID files are kept.
    # The default value is '/run'.
    rundir = /var/run/puppet

    # Where SSL certificates are kept.
    # The default value is '\$confdir/ssl'.
    ssldir = \$vardir/ssl

[agent]
    # The file in which puppetd stores a list of the classes
    # associated with the retrieved configuratiion.  Can be loaded in
    # the separate puppet executable using the --loadclasses
    # option.
    # The default value is '\$confdir/classes.txt'.
    classfile = \$vardir/classes.txt

    # Where puppetd caches the local configuration.  An
    # extension indicating the cache format is added automatically.
    # The default value is '$confdir/localconfig'.
    localconfig = \$vardir/localconfig
    pluginsync = true
    server = ${vPuppetServer}
    
    # use a generic certificate when negotiating with the puppet master
    certname = ${vEnvironmentType}.hndigital.net
    node_name = facter
    node_name_fact = fqdn
EOF

# Add puppet call to server startup
grep -q -F 'puppet agent --test' /etc/rc.local || echo 'puppet agent --test' >> /etc/rc.local

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
EOF

# Configure Server Facts
cat > /etc/facter/facts.d/server.txt <<EOF
srv_name=${vServerName}
srv_type=${vServerType}
srv_instance=${vServerInstance}
EOF

# Setup Puppet cron and Run Puppet","\n",
#### puppet resource cron puppet-agent ensure=present user=root minute=*/15 command='/usr/bin/puppet agent --onetime --no-daemonize --splay'
#### puppet agent --test