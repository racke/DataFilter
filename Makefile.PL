use ExtUtils::MakeMaker;

WriteMakefile(NAME => 'DataFilter',
    AUTHOR         => q{Stefan Hornburg (Racke) <racke@linuxia.de>},
    VERSION_FROM   => 'lib/DataFilter.pm',
    EXE_FILES      => ['./scripts/datafilter'],
    PREREQ_PM      => {
	'Test::More' => 0,
	      },
   test            => { TESTS => join( ' ', (glob( 't/*.t'), glob('t/*/*.t')))},
);
