#!/bin/bash

sed -i "/\[authenticator\]/a \  provider = pam \n  service = login" /etc/patrol.d/security_policy_v3.0/site.plc

/etc/init.d/PatrolAgent restart
