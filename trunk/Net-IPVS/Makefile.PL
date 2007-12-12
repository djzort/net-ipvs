use warnings;
use strict;

# Load the Module::Install bundled in ./inc/
use inc::Module::Install;

# Define metadata
name            'Net-IPVS';
all_from        'lib/Net/IPVS.pm';

# Runtime dependencies
requires        'Carp'              => 0;
requires        'Params::Check'     => '0.26';
requires        'Readonly'          => 0;
requires        'Regexp::Common'    => '2.120';

# Build dependencies
build_requires 'File::Spec'      => '3.24';
build_requires 'Test::Exception' => '0.25';
build_requires 'Test::More'      => '0.42';
build_requires 'IO::Capture'     => '0.05';


auto_install;
WriteAll;
