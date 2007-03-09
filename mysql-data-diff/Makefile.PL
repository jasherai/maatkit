use ExtUtils::MakeMaker;
$program = 'mysql-data-diff';

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME          => $program,
    # TODO: check later what's wrong with this
    # ABSTRACT_FROM => $program,
    VERSION_FROM  => $program,

    EXE_FILES     => [$program],
    LIBS          => [''],

    PREREQ_PM     => {
        DBI           => 0,
        DBD::mysql    => 0,
        Getopt::Long  => 0,
    },
);
