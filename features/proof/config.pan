# Configure a PROOF cluster.
# Root must be installed indepedently, preferably in a shared area, as
# there is no Root RPM.
unique template features/proof/config;

variable PROOF_CONFIG_SITE ?= null;

variable PROOF_SERVICE ?= 'xrootd';
variable PROOF_STARTUP_SCRIPT ?= '/etc/init.d/' + PROOF_SERVICE;
variable PROOF_SOCKET_DIR ?= undef;

#############################################################
# Load site config and checks mandatory params are defined. #
# Define default values for others.                         #
#############################################################

include PROOF_CONFIG_SITE;

variable XROOTD_INSTALLATION_DIR ?= error('XROOTD_INSTALLATION_DIR not defined in site configuration: no default.');
variable XROOTD_CONFIG_FILE ?= error('XROOTD_CONFIG_FILE not defined in site configuration: no default.');
variable XROOTD_DAEMON ?= XROOTD_INSTALLATION_DIR + '/bin/' + PKG_ARCH_DEFAULT + '/xrootd';
variable XROOTD_LIB_DIR ?= if ( PKG_ARCH_DEFAULT == 'i386' ) {
    XROOTD_INSTALLATION_DIR + '/lib';
} else {
    XROOTD_INSTALLATION_DIR + '/lib64';
};
variable XROOTD_USER ?= 'xrootd';

variable PROOF_MASTER_NODES ?= error('PROOF_MASTER_NODE must be defined to build the PROOF config file (no default)');
variable PROOF_WORKER_NODES ?= error('PROOF_WORKER_NODES must be defined to build the PROOF config file (no default)');


#########################
# Create startup script #
#########################

variable PROOF_STARTUP_CONTENTS ?= file_contents('features/proof/proof_startup.sh');

'/software/components/filecopy/services' = {
    SELF[escape(PROOF_STARTUP_SCRIPT)] = dict(
        'config', PROOF_STARTUP_CONTENTS,
        'owner', 'root:root',
        'perms', '0755',
    );
    SELF;
};

'/software/components/chkconfig/service' = {
    SELF[PROOF_SERVICE] = dict(
        'on', '',
        'startstop', true,
    );
    SELF;
};


#####################################
# Create configuration in sysconfig #
#####################################

include 'components/sysconfig/config';
'/software/components/sysconfig/files/xrootd/XROOTD_DIR' = XROOTD_INSTALLATION_DIR;
'/software/components/sysconfig/files/xrootd/XROOTD' = XROOTD_DAEMON;
'/software/components/sysconfig/files/xrootd/XRDUSER' = XROOTD_USER;
'/software/components/sysconfig/files/xrootd/XRDCF' = XROOTD_CONFIG_FILE;
'/software/components/sysconfig/files/xrootd/XRDLIBS' = XROOTD_LIB_DIR;


#####################################################################
# Create xrootd configuration file for PROOF.                       #
# The configuration can be passed explicitly in PROOF_XROOTD_CONFIG #
# or using a template (PROOF_XROOTD_CONFIG_TEMPLATE_FILE).          #
# In both cases, some replacements are attempted to substitute      #
# with variables describing actual configuration.                   #
#####################################################################

variable PROOF_XROOTD_CONFIG_TEMPLATE_FILE ?= 'features/proof/xrootd-config-default';

variable PROOF_XROOTD_CONFIG = {
    if ( is_defined(SELF) ) {
        contents = SELF;
    } else {
        tmp = create(PROOF_XROOTD_CONFIG_TEMPLATE_FILE);
        contents = tmp['contents'];
    };
    contents = replace('PROOF_SANDBOX_AREA', PROOF_SANDBOX_AREA, contents);

    if ( is_defined(PROOF_SOCKET_DIR) ) {
        contents = contents + "\nxpd.sockpathdir " + PROOF_SOCKET_DIR + "\n";
    };

    # If on a master, define master role and list of workers
    if ( index(FULL_HOSTNAME, PROOF_MASTER_NODES) >= 0 ) {
        # Add definition of masters
        contents = contents + "\n";
        foreach (i; master; PROOF_MASTER_NODES) {
            master_role = 'any';   # Both master and worker allowed
            if ( !is_list(PROOF_WORKER_NODES) ||
                (index(master, PROOF_WORKER_NODES) < 0) ) {
                master_role = 'master';
            };
            contents = contents + "if " + master + "\n";
            contents = contents + "  xpd.role " + master_role + "\n";
            contents = contents + "fi\n";
        };

        # Add list of worker nodes.
        # It is possible to define number of CPU to use explicitly using
        # variable PROOF_CORES which is a dict where keys are worker names.
        # Value can be either positive (number of cores to use) or negative
        # (number of cores reserved).
        contents = contents + "\n";
        foreach (i; wn; PROOF_WORKER_NODES) {
            if ( exists(DB_MACHINE[escape(wn)]) ) {
                wn_hw = create(DB_MACHINE[escape(wn)]);
            } else {
                error(wn + ": hardware not found in machine database");
            };
            cpu_num = length(wn_hw['cpu']);
            if ( cpu_num > 0 ) {
                if ( is_defined(PROOF_CORES[wn]) && (PROOF_CORES[wn] >= 0) ) {
                    core_num = PROOF_CORES[wn];
                } else if ( is_defined(wn_hw['cpu'][0]['cores']) ) {
                    # If PROOF_CORES[wn] is defined and negative, remove the given
                    # number of cores from PROOF config.
                    # Else, if WN is a master, remove 1 CPU from the WN config.
                    core_num = cpu_num * wn_hw['cpu'][0]['cores'];
                    if ( is_defined(PROOF_CORES[wn]) && (PROOF_CORES[wn] < 0) ) {
                        core_num = core_num + PROOF_CORES[wn];
                    } else if ( index(wn, PROOF_MASTER_NODES) >= 0 ) {
                        core_num = core_num -1;
                    };
                    if ( core_num < 0 ) {
                        debug('Computed number of cores to use negative. Resetting to 0.');
                        core_num = 0;
                    };
                } else {
                    core_num = cpu_num;
                };
            } else {
                error(wn + ': number of CPU not defined in HW database');
            };
            contents = contents + "xpd.worker worker " + wn + " repeat=" + to_string(core_num) + "\n";
        };
    };
    contents;
};


'/software/components/filecopy/services' = {
    if ( is_defined(PROOF_XROOTD_CONFIG) ) {
        SELF[escape(XROOTD_CONFIG_FILE)] = dict('config', PROOF_XROOTD_CONFIG,
            'owner', 'root:root',
            'perms', '0755',
            'restart', '/sbin/service xrootd restart',
        );
    };
    SELF;
};


# Must be done at the very end of the configuration
include 'features/proof/check-proof-daemons';
