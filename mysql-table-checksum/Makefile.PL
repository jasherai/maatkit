use ExtUtils::MakeMaker;
$program = 'mysql-table-checksum';

WriteMakefile(
    NAME         => $program,
    VERSION_FROM => $program,
    EXE_FILES    => [$program, 'mysql-checksum-filter'],
    PREREQ_PM    => {
        DBI           => 1.13,
        DBD::mysql    => 1.0,
    },
    LIBS   => [''],
    DEFINE => '',
    INC    => '',
);
