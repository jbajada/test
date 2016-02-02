#!/bin/bash

## Read in arguments
for i in "$@"
do
    case $i in
        -l=*|--location=*)
            envLocation="${i#*=}"
            shift # past argument
        ;;

        -b=*|--brand=*)
            envBrand="${i#*=}"
            shift # past argument
        ;;

        -e=*|--environmenttype=*)
            envEnvironmentType="${i#*=}"
            shift # past argument
        ;;

        -i=*|--instance=*)
            envInstance="${i#*=}"
            shift # past argument
        ;;

        -s=*|--servertype=*)
            envServerType="${i#*=}"
            shift # past argument
        ;;

        -c=*|--instancecount=*)
            envInstanceCount="${i#*=}"
            shift # past argument
        ;;
    
        -o=*|--owner=*)
            envOwner="${i#*=}"
            shift # past argument
        ;;

        -n=*|--servername=*)
            envServerName="${i#*=}"
            shift # past argument
        ;;

        -d=*|--description=*)
            envDescription="${i#*=}"
            shift # past argument
        ;;
        
        -u=*|--gitusername=*)
            envGitUsername="${i#*=}"
            shift # past argument
        ;;
        
        -p=*|--gitpassword=*)
            envGitPassword="${i#*=}"
            shift # past argument
        ;;

        *)
            # unknown option
        ;;
    esac

    shift # past argument or value
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
#export ssldir=$(puppet agent --genconfig | grep -e 'ssldir =' | sed -e 's/^[ \t]*//' | awk '{print $3}')
#puppet cert list --all

## Permanent Certificate Solution
##curl -u ${envGitUsername}:${envGitPassword} https://stash.harveynorman.com.au/projects/PUPPET/repos/securitykeys/browse/puppet/certs/ca.pem?raw -o $ssldir/certs/ca.pem
##curl -u ${envGitUsername}:${envGitPassword} https://stash.harveynorman.com.au/projects/PUPPET/repos/securitykeys/browse/puppet/ca/signed/${envEnvironmentType}.hndigital.net.pem?raw -o $ssldir/certs/${envEnvironmentType}.hndigital.net.pem
##curl -u ${envGitUsername}:${envGitPassword} https://stash.harveynorman.com.au/projects/PUPPET/repos/securitykeys/browse/puppet/public_keys/${envEnvironmentType}.hndigital.net.pem?raw -o $ssldir/public_keys/${envEnvironmentType}.hndigital.net.pem
##curl -u ${envGitUsername}:${envGitPassword} https://stash.harveynorman.com.au/projects/PUPPET/repos/securitykeys/browse/puppet/private_keys/${envEnvironmentType}.hndigital.net.pem?raw -o $ssldir/private_keys/${envEnvironmentType}.hndigital.net.pem

## Temporary Certificate Solution
#curl https://raw.githubusercontent.com/jbajada/test/master/puppet/certs/ca.pem -o $ssldir/certs/ca.pem
#curl https://raw.githubusercontent.com/jbajada/test/master/puppet/ca/signed/${envEnvironmentType}.hndigital.net.pem -o $ssldir/certs/${envEnvironmentType}.hndigital.net.pem
#curl https://raw.githubusercontent.com/jbajada/test/master/puppet/public_keys/${envEnvironmentType}.hndigital.net.pem?raw -o $ssldir/public_keys/${envEnvironmentType}.hndigital.net.pem
#curl https://raw.githubusercontent.com/jbajada/test/master/puppet/private_keys/${envEnvironmentType}.hndigital.net.pem?raw -o $ssldir/private_keys/${envEnvironmentType}.hndigital.net.pem

#find $ssldir/ -name '*.pem' | xargs chmod 600
#find $ssldir/ -name '*.pem' | xargs chown puppet:puppet

## Configure Puppet
#echo "pluginsync=true" >> /etc/puppet/puppet.conf
#echo "server=puppet" >> /etc/puppet/puppet.conf
#echo "" >> /etc/puppet/puppet.conf
#echo "# use a generic certificate when negotiating with the puppet master" >> /etc/puppet/puppet.conf,
#echo "certname = ${envEnvironmentType}.hndigital.net" >> /etc/puppet/puppet.conf
#echo "node_name = facter" >> /etc/puppet/puppet.conf
#echo "node_name_fact = fqdn" >> /etc/puppet/puppet.conf
#echo "puppet agent --test --waitforcert 60" >> /etc/rc.local

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