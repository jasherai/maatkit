use ExtUtils::MakeMaker;
$program = 'mysql-table-sync';

WriteMakefile(
    NAME         => $program,
    VERSION_FROM => $program,
    EXE_FILES    => [$program],
    PREREQ_PM    => {
        DBI           => 1.13,
        DBD::mysql    => 1.0,
    },
    LIBS   => [''],
    DEFINE => '',
    INC    => '',
);
