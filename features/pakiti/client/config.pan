unique template features/pakiti/client/config;

variable PAKITI_RPMS ?= if_exists('config/pakiti/client/config');
variable PAKITI_RPMS ?= 'features/pakiti/client/rpms';
include PAKITI_RPMS;

# Variables are checked in main config template

variable PAKITI_CLIENT_INSECURE ?= false;

include 'components/filecopy/config';

'/software/components/filecopy/services/{/etc/pakiti2/pakiti2-client.conf}' = dict(
    'config', format(file_contents('features/pakiti/client/pakiti2.conf'),
        PAKITI_SERVER, PAKITI_SERVER_PORT,
        PAKITI_SERVER_FEED_URL,
        PAKITI_CA_PATH,
        PAKITI_TAG,
        if (is_boolean(PAKITI_CLIENT_INSECURE) && PAKITI_CLIENT_INSECURE ) '--insecure' else '',
    ),
    'perms', '0644',
);
