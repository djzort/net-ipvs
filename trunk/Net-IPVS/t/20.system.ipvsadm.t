#------------------------------------------------------------------------------
# $Id$

use strict;
use warnings;

# Test Modules
use Test::More;
use Test::Exception;

# Extra Modules
use English qw(-no_match_vars);

#use Smart::Comments;

# Local Modules;
use Net::IPVS;

#------------------------------------------------------------------------------
# Setup

if ( !$ENV{TEST_SYSTEM} ) {
    my $msg
        = 'System test. Enabling these tests will modify your IPVS tables! '
        . 'Set $ENV{TEST_SYSTEM} to a true value to run.';
    plan( skip_all => $msg );
}

# Give the user one last chance to bail out
if ( !$ENV{TEST_AUTHOR} ) {
    print STDERR 'The following tests _will_ destroy your IPVS table. '
        . "Press Ctrl-C to skip these tests.\n";
    sleep 1 && print STDERR ( 10 - $_ ) . q{ } for ( 0 .. 10 );
}

my $port = 12345;

my @services = ( "10.1.1.20:$port", );

my @servers = map { "$_:$port" }
    ( '10.1.1.21', '10.1.1.22', '10.1.1.23', '10.1.1.24', '10.1.1.25', );

my %test_table = ( $services[0] => [@servers], );

# Check for root or sudo?
my $ipvs = Net::IPVS->new( command => 'sudo /sbin/ipvsadm' );
$ipvs->clear();

#------------------------------------------------------------------------------
# Tests

plan tests => 6;

test_add_table();
test_edit_table();
test_delete_table();

cleanup();

#------------------------------------------------------------------------------
# Subroutines

sub test_add_table {
    for my $service ( keys %test_table ) {
        $ipvs->add_service( virtual => $service );

        $ipvs->add_server( virtual => $service, server => $_ )
            for @{ $test_table{$service} };
    }

    my %ipvs_table = $ipvs->get_table();
    ### %ipvs_table

    ok(
        exists $ipvs_table{ $services[0] },
        qq{Service address $services[0] exists}
    );

    ok(
        exists $ipvs_table{ $services[0] }{ $servers[0] },
        qq{Server address $servers[0] exists for service $services[0]}
    );
}

sub test_edit_table {
    my $server = $servers[ int rand( scalar @servers ) ];

    $ipvs->edit_service(
        virtual   => $services[0],
        scheduler => 'wrr',
    );

    $ipvs->edit_server(
        virtual => $services[0],
        server  => $server,
        weight  => 0
    );

    my %ipvs_table = $ipvs->get_table();
    ### %ipvs_table

    is( $ipvs_table{ $services[0] }{Scheduler},
        'wrr', qq{Successfully changed scheduler for $services[0] to wrr} );

    is( $ipvs_table{ $services[0] }{$server}{Weight},
        0, qq{Successfully changed weight to 0 for $server} );
}

sub test_delete_table {
    my $server = $servers[ int rand( scalar @servers ) ];

    $ipvs->delete_server(
        virtual => $services[0],
        server  => $server,
    );

    my %ipvs_table = $ipvs->get_table();

    ok( !exists $ipvs_table{ $services[0] }{$server},
        qq{Server $server successfully removed from service $services[0]} );

    $ipvs->delete_service( virtual => $services[0], );

    %ipvs_table = $ipvs->get_table();

    ok(
        !exists $ipvs_table{ $services[0] },
        qq{Service $services[0] successfully removed}
    );
}

sub cleanup {
    $ipvs->clear();
}

#------------------------------------------------------------------------------

__END__
  
