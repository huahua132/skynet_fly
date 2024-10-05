#!/usr/bin/perl 
use Test2::V0;

my $engine_name = $ENV{ENGINE_NAME} || 'gost';
my $provider_name = $ENV{PROVIDER_NAME} || 'gostprov';

# Supported test types:
#
# conf                          Only if there's a command line argument.
#                               For this test type, we rely entirely on the
#                               caller to define the environment variable
#                               OPENSSL_CONF appropriately.
# standalone-engine-conf        Tests the engine through a generated config
#                               file.
#                               This is done when there are no command line
#                               arguments or when the environment variable
#                               ENGINE_NAME is defined.
# standalone-engine-args        Tests the engine through openssl command args.
#                               This is done when there are no command line
#                               arguments or when the environment variable
#                               ENGINE_NAME is defined.
# standalone-provider-conf      Tests the provider through a generated config
#                               file.
#                               This is done when there are no command line
#                               arguments or when the environment variable
#                               PROVIDER_NAME is defined.
# standalone-provider-args      Tests the provider through openssl command args.
#                               This is done when there are no command line
#                               arguments or when the environment variable
#                               PROVIDER_NAME is defined.
my @test_types = ( $ARGV[0] ? 'conf' : (),
                   ( !$ARGV[0] || $ENV{ENGINE_NAME}
                     ? ( 'standalone-engine-conf', 'standalone-engine-args' )
                     : () ),
                   ( !$ARGV[0] || $ENV{PROVIDER_NAME}
                     ? ( 'standalone-provider-conf', 'standalone-provider-args' )
                     : () ) );

plan(19 * scalar @test_types);

# prepare data for 
my $F;
open $F,">","testdata.dat";
print $F "12345670" x 128;
close $F;

open $F,">","testbig.dat";
print $F ("12345670" x 8 . "\n") x  4096;
close $F;

my $key='0123456789abcdef' x 2;
note("\@ARGV = (", join(', ', @ARGV), ")");
my %configurations = (
    'conf' => {
        'module-type'   => $ARGV[0],
    },
    'standalone-engine-args' => {
        'module-type'   => 'engine',
        'openssl-args'  => "-engine $engine_name",
    },
    'standalone-provider-args' => {
        'module-type'   => 'provider',
        'openssl-args'  => "-provider $provider_name -provider default",
    },
    'standalone-engine-conf' => {
        'module-type'   => 'engine',
        'openssl-conf'  => <<EOCFG,
openssl_conf = openssl_def
[openssl_def]
engines = engines
[engines]
${engine_name}=${engine_name}_conf
[${engine_name}_conf]
default_algorithms = ALL
EOCFG
    },
    'standalone-provider-conf' => {
        'module-type'   => 'provider',
        'openssl-conf'  => <<EOCFG,
openssl_conf = openssl_def
[openssl_def]
providers = providers
[providers]
${provider_name}=${provider_name}_conf
[${provider_name}_conf]
EOCFG
    },
);

my %executors = (
    engine => {
        mac_cmd => sub {
            my %opts = @_;
            my $cmd = "openssl dgst $opts{-args}"
                . " -mac $opts{-mac} -macopt key:$opts{-key}"
                . (defined $opts{-size} ? " -sigopt size:$opts{-size}" : "")
                . " $opts{-infile}";

            return $cmd;
        },
        check_expected => sub {
            my %opts = @_;

            return "$opts{-mac}($opts{-infile})= $opts{-result}\n";
        },
    },
    provider => {
        mac_cmd => sub {
            my %opts = @_;
            my $cmd = "openssl mac $opts{-args} -macopt key:$opts{-key}"
                . (defined $opts{-size} ? " -macopt size:$opts{-size}" : "")
                . " -in $opts{-infile} $opts{-mac}";

            return $cmd;
        },
        check_expected => sub {
            my %opts = @_;

            return uc($opts{-result})."\n";
        },
    },
);

foreach my $test_type (@test_types) {
    my $configuration = $configurations{$test_type};
    my $module_type = $configuration->{'module-type'};
    my $module_args = $configuration->{'openssl-args'} // '';
    my $module_conf = $configuration->{'openssl-conf'};
    # This is a trick to make a locally modifiable environment variable and
    # retain it's current value as a default.
    local $ENV{OPENSSL_CONF} = $ENV{OPENSSL_CONF};

  SKIP: {
      skip "No module type detected for test type '$test_type'", 19
          unless $module_type;

      note("Running tests for test type $test_type");

      if ($module_args) {
          $module_args = ' ' . $module_args;
      }
      if (defined $module_conf) {
          my $confname = "$test_type.cnf";
          open my $F, '>', $confname;
          print $F $module_conf;
          close $F;
          $ENV{OPENSSL_CONF} = abs_path($confname);
      }

      # Reopen STDERR to eliminate extra output
      #open STDERR, ">>","tests.err";

      my $mac_cmd = $executors{$module_type}->{mac_cmd};
      my $mac_expected = $executors{$module_type}->{check_expected};
      my $cmd;
      my $expected;

      $cmd = $mac_cmd->(-mac => 'gost-mac', -key => $key,
                        -args => $module_args, -infile => 'testdata.dat');
      $expected = $mac_expected->(-mac => 'GOST-MAC-gost-mac',
                                  -infile => 'testdata.dat',
                                  -result => '2ee8d13d');
      unless (is(`$cmd`, $expected, "GOST MAC - default size")) {
          diag("Command was: $cmd");
      }

      my $i;
      for ($i=1;$i<=8; $i++) {
          $cmd = $mac_cmd->(-mac => 'gost-mac', -key => $key, -size => $i,
                            -args => $module_args, -infile => 'testdata.dat');
          $expected = $mac_expected->(-mac => 'GOST-MAC-gost-mac',
                                      -infile => 'testdata.dat',
                                      -result => substr("2ee8d13dff7f037d",0,$i*2));
          unless (is(`$cmd`, $expected, "GOST MAC - size $i bytes")) {
              diag("Command was: $cmd");
          }
      }



      $cmd = $mac_cmd->(-mac => 'gost-mac', -key => $key,
                        -args => $module_args, -infile => 'testbig.dat');
      $expected = $mac_expected->(-mac => 'GOST-MAC-gost-mac',
                                  -infile => 'testbig.dat',
                                  -result => '5efab81f');
      unless (is(`$cmd`, $expected, "GOST MAC - big data")) {
          diag("Command was: $cmd");
      }

      $cmd = $mac_cmd->(-mac => 'gost-mac-12', -key => $key,
                        -args => $module_args, -infile => 'testdata.dat');
      $expected = $mac_expected->(-mac => 'GOST-MAC-12-gost-mac-12',
                                  -infile => 'testdata.dat',
                                  -result => 'be4453ec');
      unless (is(`$cmd`, $expected, "GOST MAC parameters 2012 - default size")) {
          diag("Command was: $cmd");
      }
      for ($i=1;$i<=8; $i++) {
          $cmd = $mac_cmd->(-mac => 'gost-mac-12', -key => $key, -size => $i,
                            -args => $module_args, -infile => 'testdata.dat');
          $expected = $mac_expected->(-mac => 'GOST-MAC-12-gost-mac-12',
                                      -infile => 'testdata.dat',
                                      -result => substr("be4453ec1ec327be",0,$i*2));
          unless (is(`$cmd`, $expected, "GOST MAC parameters 2012 - size $i bytes")) {
              diag("Command was: $cmd");
          }
      }
    }
}

unlink('testdata.dat');
unlink('testbig.dat');
