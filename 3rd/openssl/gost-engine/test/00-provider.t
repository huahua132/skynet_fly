#!/usr/bin/perl 
use Test2::V0;
skip_all('This test is only suitable for the provider')
    unless $ARGV[0] eq 'provider';
plan(1);
use Cwd 'abs_path';

my $provider = 'gostprov';
my $provider_info = <<EOINF;
Providers:
  gostprov
    name: OpenSSL GOST Provider
    status: active
EOINF

# Normally, this test recipe tests the default GOST provider.  However, it's
# also possible to test a different provider as well, possibly a custom build.
# In that case, use the environment variable PROVIDER_NAME to name it.  This
# overrides a few things:
#
# - if it exists, we get the text that 'openssl provider -c ${PROVIDER_NAME}'
#   should print from the file "${PROVIDER_NAME}.info".
# - we create an OpenSSL config file for that provider, and use that instead
#   of the default.  We do this by overriding the environment variable
#   OPENSSL_CONF
#
# If PROVIDER_NAME isn't set, we rely on an existing OPENSSL_CONF
#
if ($ENV{'PROVIDER_NAME'}) {
    $provider=$ENV{'PROVIDER_NAME'};

    if ( -f $provider . ".info") {
        diag("Reading $provider.info");
        open my $F, "<", $provider . ".info";
        read $F,$provider_info,1024;
        close $F;
    }

    open my $F,">","$provider.cnf";
    print $F <<EOCFG;
openssl_conf = openssl_def
[openssl_def]
providers = providers
[providers]
${provider}=gost_conf
[gost_conf]
default_algorithms = ALL
EOCFG
    close $F;
    $ENV{'OPENSSL_CONF'}=abs_path("$provider.cnf");
}

# Let's check that we can load the provider without config file
# Note that this still requires a properly defined OPENSSL_MODULES
{
    local $ENV{'OPENSSL_CONF'}=abs_path("no_such_file.cfg");
    my $cmd = "openssl list -provider $provider -providers";
    unless (is(`$cmd`, $provider_info,
               "load provider without any config")) {
        diag("Command was: $cmd");
    }
}
