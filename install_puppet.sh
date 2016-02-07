#!/bin/bash

## Read in arguments
for i in "$@"
do
    case $i in
        -l=*|--location=*)
            envLocation="${i#*=}"
        ;;

        -b=*|--brand=*)
            envBrand="${i#*=}"
        ;;

        -e=*|--environmenttype=*)
            envEnvironmentType="${i#*=}"
        ;;

        -i=*|--instance=*)
            envInstance="${i#*=}"
        ;;

        -s=*|--servertype=*)
            envServerType="${i#*=}"
        ;;

        -c=*|--instancecount=*)
            envInstanceCount="${i#*=}"
        ;;
    
        -o=*|--owner=*)
            envOwner="${i#*=}"
        ;;

        -n=*|--servername=*)
            envServerName="${i#*=}"
        ;;

        -d=*|--description=*)
            envDescription="${i#*=}"
        ;;
        
        -u=*|--gitusername=*)
            envGitUsername="${i#*=}"
        ;;
        
        -p=*|--gitpassword=*)
            envGitPassword="${i#*=}"
        ;;

        *)
            # unknown option
        ;;
    esac
done

echo ${envLocation}
echo ${envBrand}

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
##curl -u ${envGitUsername}:${envGitPassword} https://stash.harveynorman.com.au/projects/PUPPET/repos/securitykeys/browse/puppet/certs/ca.pem?raw -o $ssldir/certs/ca.pem
##curl -u ${envGitUsername}:${envGitPassword} https://stash.harveynorman.com.au/projects/PUPPET/repos/securitykeys/browse/puppet/ca/signed/${envEnvironmentType}.hndigital.net.pem?raw -o $ssldir/certs/${envEnvironmentType}.hndigital.net.pem
##curl -u ${envGitUsername}:${envGitPassword} https://stash.harveynorman.com.au/projects/PUPPET/repos/securitykeys/browse/puppet/public_keys/${envEnvironmentType}.hndigital.net.pem?raw -o $ssldir/public_keys/${envEnvironmentType}.hndigital.net.pem
##curl -u ${envGitUsername}:${envGitPassword} https://stash.harveynorman.com.au/projects/PUPPET/repos/securitykeys/browse/puppet/private_keys/${envEnvironmentType}.hndigital.net.pem?raw -o $ssldir/private_keys/${envEnvironmentType}.hndigital.net.pem

## Temporary Certificate Solution
curl https://raw.githubusercontent.com/jbajada/test/master/ssl/certs/ca.pem -o $ssldir/certs/ca.pem
curl https://raw.githubusercontent.com/jbajada/test/master/ssl/certs/${envEnvironmentType}.hndigital.net.pem -o $ssldir/certs/${envEnvironmentType}.hndigital.net.pem
curl https://raw.githubusercontent.com/jbajada/test/master/ssl/public_keys/${envEnvironmentType}.hndigital.net.pem -o $ssldir/public_keys/${envEnvironmentType}.hndigital.net.pem
curl https://raw.githubusercontent.com/jbajada/test/master/ssl/private_keys/${envEnvironmentType}.hndigital.net.pem -o $ssldir/private_keys/${envEnvironmentType}.hndigital.net.pem


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
    server = puppetmaster-azure.dev.hndigital.net
    
    # use a generic certificate when negotiating with the puppet master
    certname = ${envEnvironmentType}.hndigital.net
    node_name = facter
    node_name_fact = fqdn
EOF

# Add puppet call to server startup
grep -q -F 'puppet agent --test --waitforcert 60' /etc/rc.local || echo 'puppet agent --test --waitforcert 60' >> /etc/rc.local


## Configure Server Variables
#mkdir -p /etc/facter/facts.d
#cat > /etc/facter/facts.d/server.txt <<EOF
#server_name=${envServerName}
#server_description=${envDescription}
#server_brand=${envBrand}
#server_type=${envEnvironmentType}
#server_region=${envLocation}
#server_role=${envServerType}
#server_owner=${envOwner}
#server_public=false
#EOF

## Setup Puppet cron and Run Puppet","\n",
#puppet resource cron puppet-agent ensure=present user=root minute=*/15 command='/usr/bin/puppet agent --onetime --no-daemonize --splay'
#puppet agent --test --waitforcert 60