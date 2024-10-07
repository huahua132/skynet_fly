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

plan(16 * scalar @test_types);

# prepare data for

my %configurations = (
    'standalone-engine-args' => {
        'openssl-args'  => "-engine $engine_name",
    },
    'standalone-provider-args' => {
        'openssl-args'  => "-provider $provider_name -provider default",
    },
    'standalone-engine-conf' => {
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

foreach my $test_type (@test_types) {
    my $configuration = $configurations{$test_type};
    my $module_args = $configuration->{'openssl-args'} // '';
    my $module_conf = $configuration->{'openssl-conf'};
    # This is a trick to make a locally modifiable environment variable and
    # retain it's current value as a default.
    local $ENV{OPENSSL_CONF} = $ENV{OPENSSL_CONF};

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

    my $F;
    my $cmd;
    my $name_re;

    open $F,">","testm1.dat";
    print $F "012345678901234567890123456789012345678901234567890123456789012";
    close $F;
    $cmd = "openssl dgst${module_args} -md_gost12_256 testm1.dat";
    $name_re = qr/id-tc26-gost3411-12-256|md_gost12_256/;
    unless (like(`$cmd`,
                 qr/^${name_re}\Q(testm1.dat)= 9d151eefd8590b89daa6ba6cb74af9275dd051026bb149a452fd84e5e57b5500\E\n$/ms,
                 "GOST R 34.11-2012 256bit example 1 from standard")) {
        diag("Command was: $cmd");
    }

    $cmd = "openssl dgst${module_args} -md_gost12_512 testm1.dat";
    $name_re = qr/id-tc26-gost3411-12-512|md_gost12_512/;
    unless (like(`$cmd`,
                 qr/^${name_re}\Q(testm1.dat)= 1b54d01a4af5b9d5cc3d86d68d285462b19abc2475222f35c085122be4ba1ffa00ad30f8767b3a82384c6574f024c311e2a481332b08ef7f41797891c1646f48\E\n$/ms,
                 "GOST R 34.11-2012 512bit example 1 from standard")) {
        diag("Command was: $cmd");
    }

    unlink("testm1.dat");


    open $F,">","testm2.dat";
    print $F pack("H*","d1e520e2e5f2f0e82c20d1f2f0e8e1eee6e820e2edf3f6e82c20e2e5fef2fa20f120eceef0ff20f1f2f0e5ebe0ece820ede020f5f0e0e1f0fbff20efebfaeafb20c8e3eef0e5e2fb");
    close $F;
    $cmd = "openssl dgst${module_args} -md_gost12_256 testm2.dat";
    $name_re = qr/id-tc26-gost3411-12-256|md_gost12_256/;
    unless (like(`$cmd`,
                 qr/^${name_re}\Q(testm2.dat)= 9dd2fe4e90409e5da87f53976d7405b0c0cac628fc669a741d50063c557e8f50\E\n$/ms,
                 "GOST R 34.11-2012 256bit example 2 from standard")) {
        diag("Command was: $cmd");
    }

    $cmd = "openssl dgst${module_args} -md_gost12_512 testm2.dat";
    $name_re = qr/id-tc26-gost3411-12-512|md_gost12_512/;
    unless (like(`$cmd`,
                 qr/^${name_re}\Q(testm2.dat)= 1e88e62226bfca6f9994f1f2d51569e0daf8475a3b0fe61a5300eee46d961376035fe83549ada2b8620fcd7c496ce5b33f0cb9dddc2b6460143b03dabac9fb28\E\n$/ms,
                 "GOST R 34.11-2012 512bit example 2 from standard")) {
        diag("Command was: $cmd");
    }

    unlink("testm2.dat");


    open $F,">","testdata.dat";
    binmode $F;
    print $F "12345670" x 128;
    close $F;
    $cmd = "openssl dgst${module_args} -md_gost94 testdata.dat";
    $name_re = qr/id-GostR3411-94|md_gost94/;
    unless (like(`$cmd`,
                 qr/^${name_re}\Q(testdata.dat)= f7fc6d16a6a5c12ac4f7d320e0fd0d8354908699125e09727a4ef929122b1cae\E\n$/ms,
                 "GOST R 34.11-94 1K ascii")) {
        diag("Command was: $cmd");
    }

    $cmd = "openssl dgst${module_args} -md_gost12_256 testdata.dat";
    $name_re = qr/id-tc26-gost3411-12-256|md_gost12_256/;
    unless (like(`$cmd`,
                 qr/^${name_re}\Q(testdata.dat)= 1906512b86a1283c68cec8419e57113efc562a1d0e95d8f4809542900c416fe4\E\n$/ms,
                 "GOST R 34.11-2012 256bit 1K ascii")) {
        diag("Command was: $cmd");
    }

    $cmd = "openssl dgst${module_args} -md_gost12_512 testdata.dat";
    $name_re = qr/id-tc26-gost3411-12-512|md_gost12_512/;
    unless (like(`$cmd`,
                 qr/^${name_re}\Q(testdata.dat)= 283587e434864d0d4bea97c0fb10e2dd421572fc859304bdf6a94673d652c59049212bad7802b4fcf5eecc1f8fab569d60f2c20dbd789a7fe4efbd79d8137ee7\E\n$/ms,
                 "GOST R 34.11-2012 512bit 1K ascii")) {
        diag("Command was: $cmd");
    }

    unlink("testdata.dat");


    open $F,">","testdata2.dat";
    binmode $F;
    print $F "\x00\x01\x02\x15\x84\x67\x45\x31" x 128;
    close $F;

    $cmd = "openssl dgst${module_args} -md_gost94 testdata2.dat";
    $name_re = qr/id-GostR3411-94|md_gost94/;
    unless (like(`$cmd`,
                 qr/^${name_re}\Q(testdata2.dat)= 69f529aa82d9344ab0fa550cdf4a70ecfd92a38b5520b1906329763e09105196\E\n$/ms,
                 "GOST R 34.11-94 1K binary")) {
        diag("Command was: $cmd");
    }

    $cmd = "openssl dgst${module_args} -md_gost12_256 testdata2.dat";
    $name_re = qr/id-tc26-gost3411-12-256|md_gost12_256/;
    unless (like(`$cmd`,
                 qr/^${name_re}\Q(testdata2.dat)= 2eb1306be3e490f18ff0e2571a077b3831c815c46c7d4fdf9e0e26de4032b3f3\E\n$/ms,
                 "GOST R 34.11-2012 256bit 1K binary")) {
        diag("Command was: $cmd");
    }

    $cmd = "openssl dgst${module_args} -md_gost12_512 testdata2.dat";
    $name_re = qr/id-tc26-gost3411-12-512|md_gost12_512/;
    unless (like(`$cmd`,
                 qr/^${name_re}\Q(testdata2.dat)= 55656e5bcf795b499031a7833cd7dc18fe10d4a47e15be545c6ab3f304a4fe411c4c39de5b1fc6844880111441e0b92bf1ec2fb7840453fe39a2b70ced461968\E\n$/ms,
                 "GOST R 34.11-2012 512bit 1K binary")) {
        diag("Command was: $cmd");
    }

    unlink("testdata2.dat");

    open $F, ">","testdata3.dat";
    binmode $F;
    print $F substr("12345670" x 128,0,539);
    close $F;

    $cmd = "openssl dgst${module_args} -md_gost94 testdata3.dat";
    $name_re = qr/id-GostR3411-94|md_gost94/;
    unless (like(`$cmd`,
                 qr/^${name_re}\Q(testdata3.dat)= bd5f1e4b539c7b00f0866afdbc8ed452503a18436061747a343f43efe888aac9\E\n$/ms,
                 "GOST R 34.11-94 539 bytes")) {
        diag("Command was: $cmd");
    }

    $cmd = "openssl dgst${module_args} -md_gost12_256 testdata3.dat";
    $name_re = qr/id-tc26-gost3411-12-256|md_gost12_256/;
    unless (like(`$cmd`,
                 qr/^${name_re}\Q(testdata3.dat)= c98a17f9fadff78d08521e4179a7b2e6275f3b1da88339a3cb961a3514e5332e\E\n$/ms,
                 "GOST R 34.11-2012 256bit 539 bytes")) {
        diag("Command was: $cmd");
    }

    $cmd = "openssl dgst${module_args} -md_gost12_512 testdata3.dat";
    $name_re = qr/id-tc26-gost3411-12-512|md_gost12_512/;
    unless (like(`$cmd`,
                 qr/^${name_re}\Q(testdata3.dat)= d5ad93fbc9ed7abc1cf28d00827a052b40bea74b04c4fd753102c1bcf9f9dad5142887f8a4cceaa0d64a0a8291592413d6adb956b99138a0023e127ff37bdf08\E\n$/ms,
                 "GOST R 34.11-2012 512bit 539 bytes")) {
        diag("Command was: $cmd");
    }

    unlink "testdata3.dat";
    open $F , ">","bigdata.dat";
    binmode $F;
    print $F  ("121345678" x 7 . "1234567\n") x 4096,"12345\n";
    close $F;

    $cmd = "openssl dgst${module_args} -md_gost94 bigdata.dat";
    $name_re = qr/id-GostR3411-94|md_gost94/;
    unless (like(`$cmd`,
                 qr/^${name_re}\Q(bigdata.dat)= e5d3ac4ea3f67896c51ff919cedb9405ad771e39f0f2eab103624f9a758e506f\E\n$/ms,
                 "GOST R 34.11-94 128K")) {
        diag("Command was: $cmd");
    }

    $cmd = "openssl dgst${module_args} -md_gost12_256 bigdata.dat";
    $name_re = qr/id-tc26-gost3411-12-256|md_gost12_256/;
    unless (like(`$cmd`,
                 qr/^${name_re}\Q(bigdata.dat)= 50e935d725d9359e5991b6b7eba8b3539fca03584d26adf4c827c982ffd49367\E\n$/ms,
                 "GOST R 34.11-2012 256bit 128K")) {
        diag("Command was: $cmd");
    }

    $cmd = "openssl dgst${module_args} -md_gost12_512 bigdata.dat";
    $name_re = qr/id-tc26-gost3411-12-512|md_gost12_512/;
    unless (like(`$cmd`,
                 qr/^${name_re}\Q(bigdata.dat)= 1d93645ebfbb477660f98b7d1598e37fbf3bfc8234ead26e2246e1b979e590ac46138158a692f9a0c9ac2550758b4d0d4c9fb8af5e595a16d3760c6516443f82\E\n$/ms,
                 "GOST R 34.11-2012 512bit 128K")) {
        diag("Command was: $cmd");
    }

    unlink "bigdata.dat";
}
