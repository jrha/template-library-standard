unique template features/pakiti/client/configv3;

variable PAKITI_RPMS ?= if_exists('config/pakiti/client/config');
variable PAKITI_RPMS ?= 'features/pakiti/client/rpms';
include PAKITI_RPMS;

variable PAKITI_TAG ?= error('PAKITI_TAG is a mandatory variable');
variable PAKITI_SERVER ?=  error('PAKITI_SERVER is a mandatory variable');
variable PAKITI_SERVER_HTTP_PORT ?= 20080;
variable PAKITI_SERVER_HTTP_FEED_URL ?= '/feed-http/';
variable PAKITI_SERVER_PUB_KEY ?= error('PAKITI_SERVER_PUB_KEY is a mandatory variable');
variable PAKITI_CLIENT_SLEEP ?= '7200';
variable PAKITI_CLIENT_UPDATE_FREQ ?= "45 13 * * *";

include 'components/filecopy/config';

'/software/components/filecopy/services/{/etc/pakiti/pakiti-client.conf}' = dict(
    'config', format(file_contents('features/pakiti/client/pakiti3.conf'),
        PAKITI_TAG,
        PAKITI_SERVER, PAKITI_SERVER_HTTP_PORT, PAKITI_SERVER_HTTP_FEED_URL,
        PAKITI_SERVER_PUB_KEY,
        PAKITI_CLIENT_SLEEP,
    ),
    'perms', '0644',
);

include 'components/cron/config';
'/software/components/cron/entries' = append(SELF, dict(
    'name', 'pakiti_update',
    'user', 'root',
    'frequency', PAKITI_CLIENT_UPDATE_FREQ,
    'command', '/usr/bin/pakiti-client --conf /etc/pakiti/pakiti-client.conf'
));
