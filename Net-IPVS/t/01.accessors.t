#------------------------------------------------------------------------------
# $Id$

use strict;
use warnings;

# Test Modules
use Test::More;
use Test::Exception;

# Extra Modules
use IO::Capture::Stderr;

#use English qw(-no_match_vars);
#use Smart::Comments

# Local Modules;
use Net::IPVS;

#------------------------------------------------------------------------------
# Setup

#------------------------------------------------------------------------------
# Tests

plan tests => 4;

test_new();
test_command();
test_proc();

#------------------------------------------------------------------------------
# Subroutines

sub test_new {
    lives_ok { Net::IPVS->new() };
}

sub test_command {
    lives_ok { Net::IPVS->new( command => 'echo ipvsadm' ) } 'Set command ok';
}

sub test_proc {
    my $capture = IO::Capture::Stderr->new;
    $capture->start;

    throws_ok { Net::IPVS->new( procfile => 'not a ref' ) }
    qr/Key 'procfile' needs to be of type 'HASH'/,
        'Dies when setting to proc to non hash ref';

    $capture->stop;

    lives_ok { Net::IPVS->new( procfile => { ip_vs => '/proc/ip_vs' } ) }
    'Set procfile ok';
}

#------------------------------------------------------------------------------

__END__
