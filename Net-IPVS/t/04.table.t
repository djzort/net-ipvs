#------------------------------------------------------------------------------
# $Id$

use strict;
use warnings;

# Test Modules
use Test::More;
use Test::Exception;

# Extra Modules
use English qw(-no_match_vars);
use File::Spec;

#use Smart::Comments;

# Local Modules;
use Net::IPVS;

#------------------------------------------------------------------------------
# Setup

my $ipvs = Net::IPVS->new( command => 'echo ipvsadm' );

my %procfile = (
    ip_vs      => File::Spec->catfile( 't', 'data', 'proc', 'ip_vs' ),
    ip_vs_conn => File::Spec->catfile( 't', 'data', 'proc', 'ip_vs_conn' ),
);

my %procfile_empty = (
    ip_vs => File::Spec->catfile( 't', 'data', 'proc', 'ip_vs.empty' ),
    ip_vs_conn =>
        File::Spec->catfile( 't', 'data', 'proc', 'ip_vs_conn.empty' ),
);

my %procfile_malformed = (
    ip_vs => File::Spec->catfile( 't', 'data', 'proc', 'ip_vs.malformed' ),
    ip_vs_conn =>
        File::Spec->catfile( 't', 'data', 'proc', 'ip_vs_conn.malformed' ),
);

my %procfile_noexist = (
    ip_vs      => File::Spec->catfile( 't', 'data', 'noexist', 'ip_vs' ),
    ip_vs_conn => File::Spec->catfile( 't', 'data', 'noexist', 'ip_vs_conn' ),
);

#------------------------------------------------------------------------------
# Tests

plan tests => 12;

test_get_table();
test_get_connection_table();

#------------------------------------------------------------------------------
# Subroutines

sub test_get_table {
    dies_ok {
        $ipvs->{procfile} = {%procfile_noexist};
        $ipvs->get_table();
    };

    lives_ok {
        $ipvs->{procfile} = {%procfile_empty};
        $ipvs->get_table();
    };

    lives_ok {
        $ipvs->{procfile} = {%procfile};
        my %table_a = $ipvs->get_table();
        ok( %table_a, 'get_table() returns hash in list context' );
        ### %table_a

        my $table_b = $ipvs->get_table();
        is( ref $table_b, 'HASH',
            'get_table() returns hash reference in scalar context' );
    };

    lives_ok {
        $ipvs->{procfile} = {%procfile_malformed};
        $ipvs->get_table();
    };

}

sub test_get_connection_table {
    dies_ok {
        $ipvs->{procfile} = {%procfile_noexist};
        $ipvs->get_connection_table();
    };

    lives_ok {
        $ipvs->{procfile} = {%procfile_empty};
        $ipvs->get_connection_table();
    };

    lives_ok {
        $ipvs->{procfile} = {%procfile};
        my @table_a = $ipvs->get_connection_table();
        ok( @table_a,
            'get_connection_table() returns array in list context' );
        ### @table_a

        my $table_b = $ipvs->get_connection_table();
        is(
            ref $table_b,
            'ARRAY',
            'get_connection_table() returns array reference in scalar context'
        );
    };

    lives_ok {
        $ipvs->{procfile} = {%procfile_malformed};
        $ipvs->get_connection_table();
    };
}

#------------------------------------------------------------------------------

__END__
