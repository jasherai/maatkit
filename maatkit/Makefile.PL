use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'maatkit',
    VERSION_FROM => 'maatkit.pod',
    EXE_FILES    => [ <bin/mk-*> ],
    MAN1PODS     => { maatkit => 'maatkit.pod' },
    PREREQ_PM    => {
        DBI           => 1.13,
        DBD::mysql    => 1.0,
    },
);

eval { require Time::HiRes; };
print "Time::HiRes is needed by some utilities. Until it is installed, "
   . "some commands will not function.\n" if $@;
