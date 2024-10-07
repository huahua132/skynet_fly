#!/usr/bin/perl
use Test2::V0;
use Cwd 'abs_path';

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

plan(48 * scalar @test_types);

# prepare data for

my $key='0123456789abcdef' x 2;

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

sub crypt_test {
    my %p = @_;
    my $test_type = $p{-testtype};
    my $args = $p{-args};
    my $count = ++${$p{-count}};
    my $result_name = "$test_type$count";
    open my $f, ">", "$result_name.clear";
    print $f $p{-cleartext};
    close $f;

    $ENV{'CRYPT_PARAMS'} = $p{-paramset} if exists $p{-paramset};
    my $ccmd = "openssl enc${args} -e -$p{-alg} -K $p{-key} -iv $p{-iv} -in $result_name.clear";
    my $ctext = `$ccmd`;
    unless (is($?,0,"$p{-name} - Trying to encrypt")) {
        diag("Command was: $ccmd");
    }
    is(unpack("H*",$ctext),$p{-ciphertext},"$p{-name} - Checking that it encrypted correctly");
    open $f, ">", "$result_name.enc";
    print $f $ctext;
    close $f;
    my $ocmd = "openssl enc${args} -d -$p{-alg} -K $p{-key} -iv $p{-iv} -in $result_name.enc";
    my $otext = `$ocmd`;
    unless(is($?,0,"$p{-name} - Trying to decrypt")) {
        diag("Command was: $ocmd");
    }
    is($otext,$p{-cleartext},"$p{-name} - Checking that it decrypted correctly");
    unlink "$result_name.enc";
    unlink "$result_name.clear";
    delete $ENV{'CRYPT_PARAMS'};
}

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

    my $count=0;

    #
    # parameters -paramset = oid of the parameters
    # -cleartext - data to encrypt
    # -ciphertext - expected ciphertext (hex-encoded)
    # -key - key (hex-encoded)
    # -iv  - IV (hex-encoded)
    #
    $key = '0123456789ABCDEF' x 4;
    my $iv =  '0000000000000000';
    my $clear1 = "The quick brown fox jumps over the lazy dog\n";
    my @common_args = ( -count          => \$count,
                        -args           => $module_args,
                        -key            => $key,
                        -iv             => $iv,
                        -cleartext      => $clear1 );

    crypt_test(-paramset        => "1.2.643.2.2.31.1",
               -ciphertext      => '07f4102c6185c4a09e676e269bfa4bc9c5df6575916b879bd13a893a2285ee6690107cdeef7a315d2eb54bfa',
               -alg             => 'gost89',
               -name            => 'CFB short text, paramset A',
               @common_args);

    crypt_test(-paramset        => "1.2.643.2.2.31.2",
               -ciphertext      => '11465c1c9708033e784fbb5536f2719c38353cb488b01f195c20d4c027022e8300d98bb66c138afbe878c88b',
               -alg             => 'gost89',
               -name            => 'CFB short text, paramset B',
               @common_args);

    crypt_test(-paramset        => "1.2.643.2.2.31.3",
               -ciphertext      => '2f213b390c9b6ceb18de479686d23f4f03c76644a0aab8894b50b71a3bbb3c027ec4c2d569ba0e6a873bd46e',
               -alg             => 'gost89',
               -name            => 'CFB short text, paramset C',
               @common_args);

    crypt_test(-paramset        => "1.2.643.2.2.31.4",
               -ciphertext      => 'e835f59a7fdfd84764efe1e987660327f5d0de187afea72f9cd040983a5e5bbeb4fe1aa5ff85d623ebc4d435',
               -alg             => 'gost89',
               -name            => 'CFB short text, paramset D',
               @common_args);

    crypt_test(-paramset        => "1.2.643.2.2.31.1",
               -ciphertext      => 'bcb821452e459f10f92019171e7c3b27b87f24b174306667f67704812c07b70b5e7420f74a9d54feb4897df8',
               -alg             => 'gost89-cnt',
               -name            => 'CNT short text',
               @common_args);

    crypt_test(-paramset        => "1.2.643.2.2.31.2",
               -ciphertext      => 'bcb821452e459f10f92019171e7c3b27b87f24b174306667f67704812c07b70b5e7420f74a9d54feb4897df8',
               -alg             => 'gost89-cnt',
               -name            => 'CNT short text, paramset param doesnt affect cnt',
               @common_args);

    crypt_test(-paramset        => "1.2.643.2.2.31.1",
               -ciphertext      => 'cf3f5f713b3d10abd0c6f7bafb6aaffe13dfc12ef5c844f84873aeaaf6eb443a9747c9311b86f97ba3cdb5c4',
               -alg             => 'gost89-cnt-12',
               -name            => 'CNT-12 short text',
               @common_args);

    crypt_test(-paramset        => "1.2.643.2.2.31.2",
               -ciphertext      => 'cf3f5f713b3d10abd0c6f7bafb6aaffe13dfc12ef5c844f84873aeaaf6eb443a9747c9311b86f97ba3cdb5c4',
               -alg             => 'gost89-cnt-12',
               -name            => 'CNT-12 short text, paramset param doesnt affect cnt',
               @common_args);

    crypt_test(-paramset        => "1.2.643.2.2.31.1",
               -ciphertext      => '3a3293e75089376572da44966cd1759c29d2f1e5e1c3fa9674909a63026da3dc51a4266bff37fb74a3a07155c9ca8fcf',
               -alg             => 'gost89-cbc',
               -name            => 'CBC short text, paramset A',
               @common_args);

    crypt_test(-paramset        => "1.2.643.2.2.31.2",
               -ciphertext      => 'af2a2167b75852378af176ac9950e3c4bffc94d3d4355191707adbb16d6c8e3f3a07868c4702babef18393edfac60a6d',
               -alg             => 'gost89-cbc',
               -name            => 'CBC short text, paramset B',
               @common_args);

    crypt_test(-paramset        => "1.2.643.2.2.31.3",
               -ciphertext      => '987c0fb3d84530467a1973791e0a25e33c5d14591976f8c1573bdb9d056eb7b353f66fef3ffe2e3524583b3997123c8a',
               -alg             => 'gost89-cbc',
               -name            => 'CBC short text, paramset C',
               @common_args);

    crypt_test(-paramset        => "1.2.643.2.2.31.4",
               -ciphertext      => 'e076b09822d4786a2863125d16594d765d8acd0f360e52df42e9d52c8e6c0e6595b5f6bbecb04a22c8ae5f4f87c1523b',
               -alg             => 'gost89-cbc',
               -name            => 'CBC short text, paramset D',
               @common_args);

    if (defined $module_conf) {
        unlink "$test_type.cnf";
    }
}
