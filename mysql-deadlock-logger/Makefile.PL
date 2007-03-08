use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'         => 'mysql-deadlock-logger'
    'VERSION_FROM' => 'mysql-deadlock-logger',     # finds $VERSION
    'EXE_FILES'    => ['mysql-deadlock-logger'],
    'PREREQ_PM'    => {
        DBI           => 1.13,
        DBD::mysql    => 1.0,
    },
    'LIBS'   => [''],                # e.g., '-lm'
    'DEFINE' => '',                  # e.g., '-DHAVE_SOMETHING'
    'INC'    => '',                  # e.g., '-I/usr/include/other'
);
