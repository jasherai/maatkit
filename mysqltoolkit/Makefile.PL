use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => $program,
    VERSION_FROM => $program,
    EXE_FILES    => [$program, 'mysql-checksum-filter'],
    PREREQ_PM    => {
        DBI           => 1.13,
        DBD::mysql    => 1.0,
        Term::ReadKey => 2.10,
    },
    LIBS   => [''],
    DEFINE => '',
    INC    => '',
);
