use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME          => 'mysql-data-diff',
    # TODO: check later what's wrong with this
    # ABSTRACT_FROM => 'mysql-data-diff',
    VERSION_FROM  => 'mysql-data-diff',

    EXE_FILES     => ['mysql-data-diff'],
    LIBS          => [''],

    PREREQ_PM     => {
        DBI           => 0,
        DBD::mysql    => 0,
        Getopt::Long  => 0,
    },
);
