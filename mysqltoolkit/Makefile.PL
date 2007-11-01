use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'mysqltoolkit',
    VERSION_FROM => 'lib/mysqltoolkit.pm',
    EXE_FILES    => [ <bin/mysql-*> ],
    PREREQ_PM    => {
        DBI           => 1.13,
        DBD::mysql    => 1.0,
    },
);
