#------------------------------------------------------------------------------
# $Id$

use strict;
use warnings;

# Test Modules
use Test::More;
use Test::Exception;

# Extra Modules
use English qw(-no_match_vars);
use IO::Capture::Stderr;

#use Smart::Comments;

# Local Modules;
use Net::IPVS;

#------------------------------------------------------------------------------
# Setup

my $ipvs = Net::IPVS->new( command => 'echo ipvsadm' );

#------------------------------------------------------------------------------
# Tests

plan tests => 3;

test_run_ipvsadm();

#------------------------------------------------------------------------------
# Subroutines

sub test_run_ipvsadm {
    lives_ok { $ipvs->_run_ipvsadm( cmd => q{} ); };

    my $capture = IO::Capture::Stderr->new;
    $capture->start;

    throws_ok { $ipvs->_run_ipvsadm() }
    qr/Required option '\w+' is not provided/, 'Dies with no arguments';

    throws_ok {
        $ipvs->{command} = 'notacommand';
        $ipvs->_run_ipvsadm( cmd => q{} );
    }
    qr/Unable to run/, 'Dies with non-zero return from system call';

    $capture->stop;
}

#------------------------------------------------------------------------------

__END__
