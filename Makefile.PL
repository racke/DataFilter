use ExtUtils::MakeMaker;

WriteMakefile(NAME => 'DataFilter',
    AUTHOR         => q{Stefan Hornburg (Racke) <racke@linuxia.de>},
    VERSION_FROM   => 'lib/DataFilter.pm',
    EXE_FILES      => ['./scripts/datafilter'],
    PREREQ_PM      => {
                       'Test::More' => 0,
                       'Archive::Zip' => 0,
                       'File::MMagic' => 0,
                       'Date::Calc' => 0,
                       'Text::CSV::Encoded' => 0,
                       'Spreadsheet::ParseExcel' => 0,
                       'Spreadsheet::WriteExcel' => 0,
                       'DBIx::Easy' => 0,
                      },
   test            => { TESTS => join( ' ', (glob( 't/*.t'), glob('t/*/*.t')))},
);
