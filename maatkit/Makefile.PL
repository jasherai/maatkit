use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'maatkit',
    VERSION_FROM => 'maatkit.pod',
    EXE_FILES    => [ <bin/mk-*> ],
    MAN3PODS     => {}, # No man(3) pages, all man(1).
    MAN1PODS     => {
      'maatkit.pod' => 'blib/man1/maatkit.1p',
      map {
         (my $name = $_) =~ s/^bin.//;
         $_ => "blib/man1/$name.1p";
      } <bin/mk-*>
    },
    PREREQ_PM    => {
        DBI           => 1.13,
        DBD::mysql    => 1.0,
    },
);

eval { require Time::HiRes; };
print "Time::HiRes is needed by some utilities. Until it is installed, "
   . "some commands will not function.\n" if $@;
