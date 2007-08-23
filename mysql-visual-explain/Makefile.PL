use ExtUtils::MakeMaker;
$program = 'mysql-visual-explain';

WriteMakefile(
    NAME         => $program,
    VERSION_FROM => $program,
    EXE_FILES    => [$program],
    PREREQ_PM    => {
        DBI           => 1.13,
        DBD::mysql    => 1.0,
        Term::ReadKey => 2.10,
    },
    LIBS   => [''],
    DEFINE => '',
    INC    => '',
);
