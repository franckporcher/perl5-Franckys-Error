use 5.006;
use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Franckys::Error',
    license             => 'artistic_2',
    dist_author         => q{Franck PORCHER,PhD <franck.porcher@franckys.com>},
    dist_version_from   => 'lib/Franckys/Error.pm',
    release_status      => 'stable',
    configure_requires => {
        'Module::Build' => 0,
    },
    build_requires => {
        'Test::More'    => 0,
        'Test::Output'  => 0,
    },
    requires => {
        'Scalar::Util'          => 0,
        'Perl6::Export::Attrs'  => 0,
    },
    add_to_cleanup     => [ 'Franckys-Error-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
