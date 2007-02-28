use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'         => 'mysql-query-profiler',
    'VERSION_FROM' => 'mysql-query-profiler',     # finds $VERSION
    'EXE_FILES'    => ['mysql-query-profiler'],
    'PREREQ_PM'    => {
        DBI           => 1.13,
        DBD::mysql    => 1.0,
        Time::HiRes   => 1.1,
    },
    'LIBS'   => [''],                # e.g., '-lm'
    'DEFINE' => '',                  # e.g., '-DHAVE_SOMETHING'
    'INC'    => '',                  # e.g., '-I/usr/include/other'
);
