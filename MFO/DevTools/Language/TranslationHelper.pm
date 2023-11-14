package MFO::DevTools::Language::TranslationHelper;

use strict;
use warnings;

use File::Spec;
use File::Basename;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Language',
    'Kernel::System::Log',
    'Kernel::System::Main',
);

sub new {
    my ( $class, %param ) = @_;

    my $self = bless {}, $class;

    my $config = $Kernel::OM->Get('Kernel::Config');
    $self->{home} = $config->Get('Home') . '/';
    
    my $language = $Kernel::OM->Get('Kernel::Language');
    $self->{user_language} = $language->{UserLanguage};
    $self->{language} = $language;

    $self->{dumper} = $Kernel::OM->Get('MFO::Log::Dumper');

    return $self;
}

sub dump {
    my ( $self, $tag, $data ) = @_;
    $self->{dumper}->dump($tag, $data, 1);
}

sub init {
    my ($self, $package, $exclude) = @_;

    if ( ref $package ne 'ARRAY' ) {
        $package = [$package];
    };

    if (! $exclude) {
        $exclude = [];
    }

    if ( ref $exclude ne 'ARRAY' ) {
        $exclude = [$exclude];
    };
    
    $self->{exclude} = $exclude;


    # load the Kernel translation file
    my $main = $Kernel::OM->Get('Kernel::System::Main');
    my $languageFile = "Kernel::Language::$self->{user_language}";

    # no need to check if the file exists, because Kernel::Language already did that
    $main->Require($languageFile);
    my $dataMethod = $languageFile->can('Data');
    $dataMethod->($self);

    # create the package class references for the translation files
    my @files;
    my @packages;
    foreach my $pckg (@{$package}) {
        push @packages, 'Kernel::Language::' . $self->{user_language} . '_' . $pckg;
        push @files, $self->{home} . "Kernel/Language/$self->{user_language}_$pckg.pm";
    }
    $self->{packages} = \@packages;

    my $log = $Kernel::OM->Get('Kernel::System::Log');

    my $customTranslationModule = '';
    my $customTranslationFile   = '';

    FILE:
    for my $file (@files) {
        # next if file does not exist
        next FILE if !-f $file;
        
        # get module name based on file name
        my $module = $file =~ s/^$self->{home}(.*)\.pm$/$1/rg;
        $module =~ s/\/\//\//g;
        $module =~ s/\//::/g;


        # Do we have a toplevel language without country code?
        if ( length $self->{user_language} == 2 ) {

            # Ignore sub-language translation files like (en_GB, en_CA, ...).
            #
            # This will not work for sr_Cyrl and sr_Latn, but in this case there is no "parent"
            #   language where this could be problematic.
            next FILE if $module =~ /^Kernel::Language::[a-z]{2}_[A-Z]{2}$/;    # en_GB
            next FILE if $module =~ /^Kernel::Language::[a-z]{2}_[A-Z]{2}_/;    # en_GB_ITSM*
        }

        # Remember custom files to load at the end.
        if ( $module =~ /_Custom$/ ) {
            $customTranslationModule = $module;
            $customTranslationFile   = $file;
            next FILE;
        }

        # load translation module
        if ( !$main->Require($module) ) {
            $log->Log(
                Priority => 'error',
                Message  => "Sorry, can't load $module!",
            );
            next FILE;
        }

        my $moduleDataMethod = $module->can('Data');

        if ( !$moduleDataMethod ) {
            $log->Log(
                Priority => 'error',
                Message  => "Sorry, can't load $module! 'Data' method not found.",
            );
            next FILE;
        }

        # Execute translation map by calling module data method via reference.
        eval { $moduleDataMethod->($self) };
    }

    if ( $customTranslationModule && $main->Require($customTranslationModule) ) {
        
        my $customTranslationDataMethod = $customTranslationModule->can('Data');
        # Execute translation map by calling custom module data method via reference.
        if ($customTranslationDataMethod) {
            eval { $customTranslationDataMethod->($self) };
        } else {
            $log->Log(
                Priority => 'error',
                Message  => "Sorry, can't load $customTranslationModule! 'Data' method not found.",
            );
        }
    }

    # set the translation helper
    $self->{language}->{TranslationHelper} = $self;
}

sub checkTranslation {
    my ( $self, $text ) = @_;
    return if !$text;

    # return if the text is already translated
    return if $self->{Translation}->{$text};

    # return if the text is in the exclude list
    if ($self->{exclude}) {
        return if grep { $text =~ /$_/ } @{$self->{exclude}};
    }
    my $package_name = $self->{packages}->[0];
    my $file_path = File::Spec->catfile($self->{home}, (split /::/, $package_name) ) . ".pm";

    $self->getLines($package_name, $file_path) unless $self->{lines};

    $text = '        # \'' . $text . '\' => \'' . $text . '\'';

    if (! grep { $_ eq $text } @{$self->{lines}}) {
        push @{$self->{lines}}, $text;
        $self->replace_lines_between_markers($file_path, $self->{lines});
    }
}

sub getLines {
    my ($self, $package_name, $file_path) = @_;

    my $start_marker = '# $$ START TranslationHelper $$';
    my $end_marker = '# $$ END TranslationHelper $$';

    # if the file does not exist, create it
    if (! -f $file_path) {
        $self->create_language_module($package_name, $file_path);
        $self->{lines} = [];
    } else {
        $self->read_lines_between_markers( $file_path, $start_marker, $end_marker );
    }
}

sub read_lines_between_markers {
    my ($self, $file_path, $start_marker, $end_marker) = @_;

    $self->ensure_markers_in_file($file_path, $start_marker, $end_marker);

    open my $fh, '<', $file_path or die "Could not open file '$file_path': $!";

    my $inside_section = 0;
    my @lines;

    while (my $line = <$fh>) {
        chomp $line; # Remove newline character

        if ($line =~ /\Q$start_marker\E/) {
            $inside_section = 1;
            next; # Skip the start marker
        }

        # Check for the end marker
        if ($line =~ /\Q$end_marker\E/) {
            $inside_section = 0;
            last; # Exit the loop, as we've found the end marker
        }

        # If we're between the markers, add the line to the list
        push @lines, $line if $inside_section;
    }
    $self->{lines} = \@lines;

    close $fh;
}

sub ensure_markers_in_file {
    my ($self, $filename, $start_marker, $end_marker) = @_;

    # Read the file and store the lines
    open my $fh, '<', $filename or die "Could not open file '$filename': $!";
    my @lines = <$fh>;
    close $fh;

    # Check for the presence of markers
    my $has_start_marker = grep { /\Q$start_marker\E/ } @lines;
    my $has_end_marker   = grep { /\Q$end_marker\E/ } @lines;

    # If both markers exist, no changes are required
    return if $has_start_marker && $has_end_marker;

    # Find the position to insert the markers
    my $insert_position;
    for (my $i = 0; $i <= $#lines; $i++) {
        if ($lines[$i] =~ /\$Self->\{Translation\} = \{/) {
            $insert_position = $i + 1;
            last;
        }
    }

    # Insert markers if a position was found
    if (defined $insert_position) {
        splice @lines, $insert_position, 0, "\n        $start_marker\n", "        $end_marker\n\n";
    } else {
        # Handle the case where the insertion point wasn't found
        warn "Insertion point not found in file";
        return;
    }

    # Write the modified content back to the file
    open $fh, '>', $filename or die "Could not open file '$filename' for writing: $!";
    print $fh @lines;
    close $fh;
}

sub replace_lines_between_markers {
    my ($self, $file_path, $new_lines) = @_;
    # Read the file and store the lines
    open my $fh, '<', $file_path or die "Could not open $file_path for reading: $!";
    my @lines = <$fh>;
    close $fh;

    # Process the lines
    my $inside_section = 0;
    my @new_file_content;
    # append \n to each new line
    @$new_lines = map { $_ =~ /\n$/ ? $_ : "$_\n" } @$new_lines;
    foreach my $line (@lines) {
        if ($line =~ /#\s*\$\$ START TranslationHelper \$\$/) {
            $inside_section = 1;
            push @new_file_content, $line, @$new_lines;
            next;
        }
        if ($line =~ /#\s*\$\$ END TranslationHelper \$\$/) {
            $inside_section = 0;
        }
        push @new_file_content, $line unless $inside_section;
    }

    # Write the modified content back to the file
    open $fh, '>', $file_path or die "Could not open $file_path for writing: $!";
    print $fh @new_file_content;
    close $fh;
}

sub create_language_module {
    my ($self, $package_name, $file_path) = @_;

    # Convert package name to file path
    my $file_dir = dirname($file_path);

    # Check if the file already exists
    if (-e $file_path) {
        print "File $file_path already exists.\n";
        return;
    }

    # Create directory if it does not exist
    if (!-d $file_dir) {
        mkdir $file_dir or die "Could not create directory $file_dir: $!";
    }

    # Create and write to the file
    open my $fh, '>', $file_path or die "Could not open $file_path for writing: $!";
    print $fh <<"END_OF_FILE";
package $package_name;

use strict;
use warnings;
use utf8;

sub Data {
    my \$Self = shift;

    # \$\$START\$\$

    \$Self->{Translation} = {

        # \$\$ START TranslationHelper \$\$
        # \$\$ END TranslationHelper \$\$

        %{\$Self->{Translation}},
    };

    # \$\$STOP\$\$
    return;
}

1;
END_OF_FILE

    close $fh;
}

1;