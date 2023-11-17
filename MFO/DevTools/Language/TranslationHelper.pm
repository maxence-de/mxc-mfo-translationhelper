# --
# Copyright (C) 2023 maxence business consulting gmbh
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (GPL-3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --
package MFO::DevTools::Language::TranslationHelper;

use strict;
use warnings;

use File::Basename;

our $VERSION = '1.0.0';

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Language',
);

sub new {
    my ( $class, %param ) = @_;

    my $self = bless {}, $class;

    $self->{home} = $Kernel::OM->Get('Kernel::Config')->{Home} . '/';
    $self->{language} = $Kernel::OM->Get('Kernel::Language');

    return $self;
}

#---------------------------------------------------------------------------------------------------------
# init($self, $package, $exclude)
#
# Initializes the TranslationHelper module to identify missing translations for supplied packages.
#
# Parameters:
#     $self:      The object instance.
#     $package:   A package name or an array reference of package names for identifying missing translations.
#     $exclude:   An optional array reference of regular expressions to exclude specific translations.
#
# Returns:
#     None
#
# Description:
#     This function initializes the TranslationHelper module to identify missing translations for the
#     specified packages. It performs the following steps:
#
#     1. Checks if package names for identifying missing translations are provided. If not, it returns early.
#     2. Converts a single package name to an array if necessary.
#     3. Handles exclusion patterns, converting a single exclusion to an array if provided.
#     4. Loads the Kernel translation file for the user's language.
#     5. Creates package class references for the translation files associated with the provided packages.
#     6. Loads and executes the translation modules for each package.
#     7. Sets the TranslationHelper ($self) into the default Language object to identify missing translations.
#
# Example:
#     $self->init('MyPackage'); # Initializes the TranslationHelper to identify missing translations for 
#    'MyPackage', which will be expanded to de_MyPackage, en_MyPackage, etc. depending on the user's language.
#
# Note:
#     - This function is designed to identify missing translations for the supplied packages only, ignoring
#       translations from other installed packages.
#     - It does not set up translation capabilities for Znuny but rather enhances the identification of
#       missing translations in the specified packages.
#---------------------------------------------------------------------------------------------------------
sub init {
    my ($self, $package, $exclude) = @_;

    # do not load the translation helper if no package(s) are given
    return unless $package;

    # if only one package is given, convert it to an array
    if ( ref $package ne 'ARRAY' ) {
        $package = [$package];
    };

    # if no exclude list is given, create an empty one
    if (! $exclude) {
        $exclude = [];
    }

    # if only one exclude is given, convert it to an array
    if ( ref $exclude ne 'ARRAY' ) {
        $exclude = [$exclude];
    };
    $self->{exclude} = $exclude;

    my $userLanguage = $self->{language}{UserLanguage};

    # load the Kernel translation file
    my $systemLanguagePackage = "Kernel::Language::$userLanguage";
    $self->requireLanguagePackage($systemLanguagePackage);

    # create the package class references for the translation files
    my @packages;
    foreach my $package (@{$package}) {
        push @packages, 'Kernel::Language::' . $userLanguage . '_' . $package;
    }

    my $first = 1;
    for my $package (@packages) {
        if ( length $userLanguage == 2 ) {
            next if $package =~ /^Kernel::Language::[a-z]{2}_[A-Z]{2}$/;    # en_GB
            next if $package =~ /^Kernel::Language::[a-z]{2}_[A-Z]{2}_/;    # en_GB_ITSM*
        }

        $self->requireLanguagePackage($package, $first);
        $self->requireLanguagePackage($package . "_Custom");
        $first = 0;
    }

    # set the translation helper
    $self->{language}->{TranslationHelper} = $self;
}

#---------------------------------------------------------------------------------------------------------
# requireLanguagePackage()
#
# Loads and initializes a language package, optionally storing the file name of the first package loaded.
#
#     $Self->requireLanguagePackage($package, $first);
#
# Parameters:
#     $package: The name of the language package to load, in the form of 'Kernel::Language::PackageName'.
#     $first (optional): A flag to indicate if this is the first package loaded. If true, the file name
#                        of the first loaded package will be stored.
#
# Returns:
#     None.
#
# Example:
#     $Self->requireLanguagePackage('Kernel::Language::YourPackage', 1);
#
# Note:
#     1. This function attempts to load the specified language package by converting the package name
#        into a file path and using Perl's 'require' function.
#     2. If the 'require' operation fails (e.g., package not found), it will catch the error and return
#        without raising an exception.
#     3. It checks if the loaded package has a 'Data' method and applies it if available.
#     4. The file name of the first loaded package can be stored if the '$first' flag is set to true.
#---------------------------------------------------------------------------------------------------------
sub requireLanguagePackage {
    my ($self, $package, $init) = @_;

    # return if we do not have a package
    return unless $package;

    # store the first package and store its default file name
    if ($init) {
        $self->{package} = $package;
        my $file = $package =~ s{::}{/}smxgr;
        $self->{file} = $self->{home} . $file . '.pm';
    }

    # try to load the package and return if it fails
    my $file = $package =~ s{::}{/}smxgr;
    $file = $file . '.pm';
    eval { require $file; };
    return if $@;

    # replace the file name with the real one
    $self->{file} = $INC{$file} if $init;

    # return if the package does not have a Data method
    my $dataMethod = $package->can('Data');
    return unless $dataMethod;
    
    # apply package translation
    eval { $dataMethod->($self) };
}

#---------------------------------------------------------------------------------------------------------
# checkTranslation($self, $text)
#
# Checks if a given translation text needs to be added to a list of lines for a specified package and file.
#
# Parameters:
#     $self:    The object instance.
#     $text:    The translation text to be checked and potentially added.
#
# Returns:
#     None
#
# Description:
#     This function checks whether the provided translation text should be added to a list of lines for a
#     specified package and file. It performs the following checks:
#
#     1. If the provided $text is empty or undefined, the function returns immediately.
#     2. It checks if the $text is already present in the object's 'Translation' hash. If so, it returns
#        immediately to avoid duplicates.
#     3. If the object has an 'exclude' list, it checks if the $text matches any of the regular expressions
#        in the 'exclude' list. If there is a match, the function returns, excluding the text.
#     4. It retrieves package and file information from the object's data structure.
#     5. It calls the 'getLines' method to retrieve lines associated with the package and file unless they
#        are already cached in the object.
#     6. It formats the $text for inclusion in the lines.
#     7. If the formatted $text is not already in the lines, it appends it to the lines array.
#     8. It calls the 'replaceLinesBetweenMarkers' method to update the file with the modified lines.
#
# Example:
#     $self->checkTranslation('Hello, World!'); # Checks and potentially adds the translation text.
#
# Note:
#     - This function is used for managing translation text and ensuring uniqueness within the lines.
#     - It is assumed that the object ($self) is properly initialized with package and file information.
#---------------------------------------------------------------------------------------------------------
sub checkTranslation {
    my ( $self, $text ) = @_;
    return if !$text;

    # return if we do not have a package
    my $package = $self->{package};
    return unless $package;
        
    my $file = $self->{file};

    # return if the text is already translated
    return if $self->{Translation}->{$text};

    # return if the text is in the exclude list
    if ($self->{exclude}) {
        return if grep { $text =~ /$_/ } @{$self->{exclude}};
    }
    
    $self->getLines($package, $file) unless $self->{lines};

    $text = '        # \'' . $text . '\' => \'' . $text . '\',';

    if (! grep { $_ eq $text } @{$self->{lines}}) {
        push @{$self->{lines}}, $text;
        $self->replaceLinesBetweenMarkers($file, $self->{lines});
    }
}

#---------------------------------------------------------------------------------------------------------
# getLines($self, $package, $file)
#
# Retrieves lines of code between specified markers in a file associated with a package.
#
# Parameters:
#     $self:      The object instance.
#     $package:   The package name.
#     $file:      The file path to read lines from.
#
# Returns:
#     None
#
# Description:
#     This function retrieves lines of code between specified start and end markers in a file associated
#     with a package. If the file does not exist, it creates the file with default content.
#
# Example:
#     $self->getLines('MyPackage', '/path/to/file.txt'); # Retrieves lines from the specified file.
#
# Note:
#     - This function is used to manage the content of language module files.
#     - It assumes that the file and markers are properly structured.
#---------------------------------------------------------------------------------------------------------
sub getLines {
    my ($self, $package, $file) = @_;

    my $startMarker = '# $$ START TranslationHelper $$';
    my $endMarker = '# $$ END TranslationHelper $$';

    # does not do anything if the file exists
    $self->createLanguageModule($package, $file);
    
    # read the TranslationHelper section
    $self->readLinesBetweenMarkers( $file, $startMarker, $endMarker );
}

#---------------------------------------------------------------------------------------------------------
# readLinesBetweenMarkers($self, $file, $startMarker, $endMarker)
#
# Reads lines of code between specified markers in a file.
#
# Parameters:
#     $self:       The object instance.
#     $file:       The file path to read lines from.
#     $startMarker: The start marker string.
#     $endMarker:   The end marker string.
#
# Returns:
#     None
#
# Description:
#     This function reads lines of code between specified start and end markers in a file. It ensures that
#     the markers are present in the file to facilitate reading.
#
# Example:
#     $self->readLinesBetweenMarkers('/path/to/file.txt', '# START', '# END'); # Reads lines between markers.
#
# Note:
#     - This function assumes that the markers are properly structured in the file.
#---------------------------------------------------------------------------------------------------------
sub readLinesBetweenMarkers {
    my ($self, $file, $startMarker, $endMarker) = @_;

    $self->ensureMarkersInFile($file, $startMarker, $endMarker);

    open my $fh, '<', $file or die "Could not open file '$file': $!";

    my $insideSection = 0;
    my @lines;

    while (my $line = <$fh>) {
        chomp $line; # Remove newline character

        if ($line =~ /\Q$startMarker\E/) {
            $insideSection = 1;
            next; # Skip the start marker
        }

        # Check for the end marker
        if ($line =~ /\Q$endMarker\E/) {
            $insideSection = 0;
            last; # Exit the loop, as we've found the end marker
        }

        # If we're between the markers, add the line to the list
        push @lines, $line if $insideSection;
    }
    $self->{lines} = \@lines;

    close $fh;
}

#---------------------------------------------------------------------------------------------------------
# ensureMarkersInFile($self, $file, $startMarker, $endMarker)
#
# Ensures that start and end markers exist in a file and inserts them if necessary.
#
# Parameters:
#     $self:       The object instance.
#     $file:       The file path to insert markers into.
#     $startMarker: The start marker string.
#     $endMarker:   The end marker string.
#
# Returns:
#     None
#
# Description:
#     This function checks whether start and end markers exist in a file. If they are not present, it inserts
#     them at an appropriate position in the file to facilitate reading and modification.
#
# Example:
#     $self->ensureMarkersInFile('/path/to/file.txt', '# START', '# END'); # Ensures markers exist in the file.
#
# Note:
#     - This function assumes that the file has a suitable insertion point for markers.
#---------------------------------------------------------------------------------------------------------
sub ensureMarkersInFile {
    my ($self, $file, $startMarker, $endMarker) = @_;

    # Read the file and store the lines
    open my $fh, '<', $file or die "Could not open file '$file': $!";
    my @lines = <$fh>;
    close $fh;

    # Check for the presence of markers
    my $hasStartMarker = grep { /\Q$startMarker\E/ } @lines;
    my $hasEndMarker   = grep { /\Q$endMarker\E/ } @lines;

    # If both markers exist, no changes are required
    return if $hasStartMarker && $hasEndMarker;

    # Find the position to insert the markers
    my $cursor;
    for (my $i = 0; $i <= $#lines; $i++) {
        if ($lines[$i] =~ /\$Self->\{Translation\} = \{/) {
            $cursor = $i + 1;
            last;
        }
    }

    # Insert markers if a position was found
    if (defined $cursor) {
        splice @lines, $cursor, 0, "\n        $startMarker\n", "        $endMarker\n\n";
    } else {
        # Handle the case where the insertion point wasn't found
        warn "Insertion point not found in file";
        return;
    }

    # Write the modified content back to the file
    open $fh, '>', $file or die "Could not open file '$file' for writing: $!";
    print $fh @lines;
    close $fh;
}

#---------------------------------------------------------------------------------------------------------
# replaceLinesBetweenMarkers($self, $file, $newLines)
#
# Replaces lines of code between specified markers in a file with new lines.
#
# Parameters:
#     $self:      The object instance.
#     $file:      The file path to replace lines in.
#     $newLines:  An array reference containing the new lines to replace the existing ones.
#
# Returns:
#     None
#
# Description:
#     This function replaces lines of code between specified start and end markers in a file with new lines.
#     It ensures that the file content is updated accordingly.
#
# Example:
#     $self->replaceLinesBetweenMarkers('/path/to/file.txt', \@newLines); # Replaces lines in the file.
#
# Note:
#     - This function assumes that the markers and new lines are properly structured.
#---------------------------------------------------------------------------------------------------------
sub replaceLinesBetweenMarkers {
    my ($self, $file, $newLines) = @_;

    # Read the file and store the lines
    open my $fh, '<', $file or die "Could not open $file for reading: $!";
    my @lines = <$fh>;
    close $fh;
    
    my $insideSection = 0;
    my @newFileContent;
    # append \n to each new line
    my @newLines = map { $_ =~ /\n$/ ? $_ : "$_\n" } @$newLines;
    foreach my $line (@lines) {
        if ($line =~ /#\s*\$\$ START TranslationHelper \$\$/) {
            $insideSection = 1;
            push @newFileContent, $line, @newLines;
            next;
        }
        if ($line =~ /#\s*\$\$ END TranslationHelper \$\$/) {
            $insideSection = 0;
        }
        push @newFileContent, $line unless $insideSection;
    }

    # Write the modified content back to the file
    open $fh, '>', $file or die "Could not open $file for writing: $!";
    print $fh @newFileContent;
    close $fh;
}

#---------------------------------------------------------------------------------------------------------
# createLanguageModule($self, $package, $file)
#
# Creates a language module file with default content for a specified package.
#
# Parameters:
#     $self:      The object instance.
#     $package:   The package name.
#     $file:      The file path to create.
#
# Returns:
#     None
#
# Description:
#     This function creates a language module file for a specified package if it does not already exist.
#     It initializes the file with default content, including start and end markers.
#
# Example:
#     $self->createLanguageModule('MyPackage', '/path/to/file.txt'); # Creates a language module file.
#
# Note:
#     - This function assumes that the directory structure for the file exists.
#     - It initializes the file with default content for managing translations.
#---------------------------------------------------------------------------------------------------------
sub createLanguageModule {
    my ($self, $package, $file) = @_;

    # Return if the file already exists
    return if (-e $file);

    # Convert package name to file path
    my $dir = dirname($file);

    $self->{lines} = [];

    # Create directory if it does not exist
    mkdir $dir or die "Could not create directory $dir: $!" unless -d $dir;

    # Create and write to the file
    open my $fh, '>', $file or die "Could not open $file for writing: $!";
    print $fh <<"END_OF_FILE";
package $package;

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

sub dump {
    # my ( $self, $tag, $data ) = @_;
    # my $dumper = $self->{dumper} ||= $Kernel::OM->Get('MFO::Log::Dumper');
    # $self->{dumper}->dump($tag, $data, 1);
}

1;