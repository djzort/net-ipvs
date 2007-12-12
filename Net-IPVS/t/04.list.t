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

test_list();
test_list_connection();

#------------------------------------------------------------------------------
# Subroutines

sub test_list {
    dies_ok {
        $ipvs->{procfile} = {%procfile_noexist};
        $ipvs->list();
    };

    lives_ok {
        $ipvs->{procfile} = {%procfile_empty};
        $ipvs->list();
    };

    lives_ok {
        $ipvs->{procfile} = {%procfile};
        my %list_a = $ipvs->list();
        ok( %list_a, 'list() returns hash in list context' );

        my $list_b = $ipvs->list();
        is( ref $list_b, 'HASH',
            'list() returns hash reference in scalar context' );
    };

    lives_ok {
        $ipvs->{procfile} = {%procfile_malformed};
        $ipvs->list();
    };

}

sub test_list_connection {
    dies_ok {
        $ipvs->{procfile} = {%procfile_noexist};
        $ipvs->list_connection();
    };

    lives_ok {
        $ipvs->{procfile} = {%procfile_empty};
        $ipvs->list_connection();
    };

    lives_ok {
        $ipvs->{procfile} = {%procfile};
        my @list_a = $ipvs->list_connection();
        ok( @list_a, 'list_connection() returns array in list context' );

        my $list_b = $ipvs->list_connection();
        is( ref $list_b, 'ARRAY',
            'list_connection() returns array reference in scalar context' );
    };

    lives_ok {
        $ipvs->{procfile} = {%procfile_malformed};
        $ipvs->list_connection();
    };
}

#------------------------------------------------------------------------------

__END__
