#!/bin/sh

if [ "$1" = '-v' ]; then 
	echo "BPPM PATROL Installer 9.6.00 (build:20142450638)"
	exit 0;
fi

#add preload km support for bill
if [ "$1" = '-preloadkms' ]; then 
	preload='true'
fi
skipval='false'
if [ "$1" = '-skipval' ]; then 
	skipval='true'
fi

DONE(){
    exit 1
}
ERROR(){
    ERMSGSTAMP=`date "+%H:%M %m/%d/%Y"`
    echo "[$ERMSGSTAMP]:ERROR: Agent configuration modification failed"
    echo "[$ERMSGSTAMP]:ERROR: $1"
    DONE 1
}

if [ ! -f install.ctl ]; then
    echo "Unable to open the install.ctl file."
    exit 1
fi
PWD=`pwd`
LIBPATH=.
export LIBPATH

PATH=$PATH:/bin
export PATH

LD_LIBRARY_PATH=.
export LD_LIBRARY_PATH

location=`cat install.ctl |grep "/BMC/INSTBASE/NOSLASH=" | cut -d"=" -f2-`
patrol3=`cat install.ctl |grep "/BMC/PATROL/DIR=" | cut -d"=" -f2-`
port=`cat install.ctl |grep "/BMC/AGENT/PORT=" | cut -d"=" -f2-`
agentStart=`cat install.ctl |grep "/BMC/AGENT/START=" | cut -d"=" -f2-`
userPassword=`cat install.ctl |grep "/ACCOUNT/passwd=" | cut -d"=" -f2-`
userName=`cat install.ctl |grep "/ACCOUNT/Quotedlogin=" | cut -d"=" -f2-`
bmcBase=`cat install.ctl |grep "/BMC/BASE=" | cut -d"=" -f2-`
rootPassword=`cat install.ctl |grep "/root/passwd=" | cut -d"=" -f2-`
rootUserName=`cat install.ctl |grep "/root/login=" | cut -d"=" -f2-`
hostName=`hostname`
if [ "$bmcBase" = "" ]; then 
    echo "The install.ctl file is invalid, BMC Base directory is missing."
    exit 1
fi
if [ "$patrol3" = "" ]; then 
    echo "The install.ctl file is invalid, Patrol3 directory is missing."
    exit 1
fi
echo $bmcBase |grep ":\\*"
retVal=`echo $?`
if [ $retVal -eq 0 ];then
    echo The directory $bmcBase is invalid 
    exit 1
fi

KERNEL=`uname -s`
PLATFORM=`uname -m`
if [ "$KERNEL" = 'Linux' ]; then 
    if [ "$PLATFORM" = 's390' ]; then
        OSNAME=LINUX-S390
    else
        if [ "$PLATFORM" = 's390x' ]; then
            OSNAME=LINUX-S390
        else
		if [ "$PLATFORM" = 'x86_64' ]; then
			OSNAME=LINUX-X64
		else
            		OSNAME=LINUX-X86
	    	fi
        fi
    fi
fi

if [ "$KERNEL" = "HP-UX" ]; then 
    OSNAME="HPUX"
fi

if [ "$KERNEL" = "SunOS" ]; then 
    if [ "$PLATFORM" = 'sun4u' ]; then
        OSNAME=SOLARIS-SPARC
    else
        if [ "$PLATFORM" = 'sun4v' ]; then
            OSNAME=SOLARIS-SPARC
        else
            OSNAME=SOLARIS-X86
        fi
    fi
fi

if [ "$KERNEL" = "AIX" ]; then 
    OSNAME="AIX"
fi

cd Install/instbin/

if [ "$KERNEL" = "HP-UX" ]; then
    LANG=en_US.iso88591; export LANG
    LC_ALL=en_US.iso88591; export LC_ALL
else
    x=`locale -a | grep en_US$`;
    if [ "$x" = "en_US" ]; then
        LANG=en_US; export LANG
        LC_ALL=en_US; export LC_ALL
    fi
fi

if [ "$skipval" = "false" ]; then 
	if [ "$userName" != "" ] ;then
		if [ "$userPassword" != "" ] ;then
			./validate.$OSNAME $userName $userPassword > /dev/null
			retVal=`echo $?`
			if [ $retVal -eq 1 ];then
				echo "The PATROL account user $userName does not exist."
				exit 1
			fi
			if [ $retVal -eq 2 ] ;then
				echo "The PATROL account username or password is incorrect."
				exit 2
			fi
			if [ $retVal -ne 0 ] ;then
				echo "An unexpected error occurred while validating the PATROL account username and password."
				exit 2
			fi
		fi
	fi
	if [ "$rootUserName" != "" ] ;then
		if [ "$rootPassword" != "" ] ;then
			./validate.$OSNAME $rootUserName $rootPassword > /dev/null
			retVal=`echo $?`
			if [ $retVal -eq 1 ];then
			echo "The Root User $rootUserName does not exists."
			exit 1
			fi
			if [ $retVal -eq 2 ]; then
			echo "The root user name or password is incorrect."
			exit 2
			fi
			if [ $retVal -ne 0 ] ;then
			echo "An unexpected error occurred while validating the root username and password."
			exit 2
			fi
		fi
	fi
fi
cd ../../
currDate=`date +"%Y_%m_%d_%H_%M_%S"`
install='_install'
sep='_'
logDir=$currDate$install
logFile=$hostName$sep$port$install
mkdir -p $bmcBase/log/$logDir
if [ $? -ne 0 ]; then
    echo "You do not have write permission for $bmcBase."
    exit 1
fi

Install/instbin/install.sh -install $PWD/install.ctl -log $bmcBase/log/$logDir/$logFile 2>$bmcBase/log/$logDir/RunSilentInstall.err 1>$bmcBase/log/$logDir/RunSilentInstall.log
#Install/instbin/preconfigure.$OSNAME -f $PWD/preconfigure.cfg $PWD/install.ctl

retVal=`echo $?`
if [ $retVal -ne 0 ];then
    echo "Installation failed. See the PATROL installation log files for detailed information. "
    exit 1
else
	echo "Installation completed successfully."
fi

if [ "$preload" = "true" ]; then 
	PATROL_RC="$location/$patrol3"
	if [ ! -f $PATROL_RC/patrolrc.sh ];then
		ERROR "Unable to locate patrolrc.sh on $PATROL_RC "
	fi
	cd $PATROL_RC
	. ./patrolrc.sh

	KMList='UNIX3.kml'
	output='PATROL_CONFIG \n"/AgentSetup/preloadedKMs" = { \n 	MERGE = "'
	for km in $KMList ; do
		#echo found $km 
		output="${output} ${km} "
	done 
	output="${output}"'"'"\n } "
	if [ "$KERNEL" = "Linux" ]; then 
		echo -e $output >/tmp/$hostName.cfg
	else
		echo $output >/tmp/$hostName.cfg
	fi

	if [ "$agentStart" != "" ]; then
		if [ "$agentStart" = "TRUE" ]; then
			pconfig -port $port -host $hostName /tmp/$hostName.cfg  > /dev/null  2>&1
		else
			PatrolAgent -p $port -batch -config /tmp/$hostName.cfg > /dev/null  2>&1
		fi
	fi
	rm /tmp/$hostName.cfg
fi
