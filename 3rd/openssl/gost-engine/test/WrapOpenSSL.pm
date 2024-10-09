#! /usr/bin/env perl
#
# CC0 license applied, see LICENSE.md

package WrapOpenSSL;
use strict;
use warnings;

use File::Basename;
use File::Spec::Functions;

sub load {
    my ($class, $p) = @_;
    my $app  = $p->{app_prove};

    # turn on verbosity
    my $verbose = $ENV{CTEST_INTERACTIVE_DEBUG_MODE} || $app->verbose();
    $app->verbose( $verbose );

    my $openssl_libdir = dirname($ENV{OPENSSL_CRYPTO_LIBRARY})
        if $ENV{OPENSSL_CRYPTO_LIBRARY};
    my $openssl_bindir = dirname($ENV{OPENSSL_PROGRAM})
        if $ENV{OPENSSL_PROGRAM};
    my $openssl_rootdir = $ENV{OPENSSL_ROOT_DIR};
    my $openssl_rootdir_is_buildtree =
        $openssl_rootdir && -d catdir($openssl_rootdir, 'configdata.pm');

    unless ($openssl_libdir) {
        $openssl_libdir = $openssl_rootdir_is_buildtree
            ? $openssl_rootdir
            : catdir($openssl_rootdir, 'lib');
    }
    unless ($openssl_bindir) {
        $openssl_bindir = $openssl_rootdir_is_buildtree
            ? catdir($openssl_rootdir, 'apps')
            : catdir($openssl_rootdir, 'bin');
    }

    if ($openssl_libdir) {
        # Variants of library paths
        $ENV{$_} = join(':', $openssl_libdir, $ENV{$_} // ())
            foreach (
                     'LD_LIBRARY_PATH',    # Linux, ELF HP-UX
                     'DYLD_LIBRARY_PATH',  # MacOS X
                     'LIBPATH',            # AIX, OS/2
            );
        if ($verbose) {
            print STDERR "Added $openssl_libdir to:\n";
            print STDERR "  LD_LIBRARY_PATH, DYLD_LIBRARY_PATH, LIBPATH\n";
        }
    }

    if ($openssl_bindir) {
        # Binary path, works the same everywhere
        $ENV{PATH} = join(':', $openssl_bindir, $ENV{PATH});
        if ($verbose) {
            print STDERR "Added $openssl_bindir to:\n";
            print STDERR "  PATH\n";
        }
    }
    if ($verbose) {
        print STDERR "$_=", $ENV{$_} // '', "\n"
            foreach qw(LD_LIBRARY_PATH DYLD_LIBRARY_PATH LIBPATH PATH);
    }
}

1;
