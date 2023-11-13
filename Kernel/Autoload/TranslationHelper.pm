use Kernel::Language;

{
    no warnings 'once';
    
    *Kernel::Language::initTranslationHelper = sub {
        my ($Self, $package, $target) = @_;
        $Self->{target} = $target;
        $Self->{package} = $package;

        # 0=off; 1=on; 2=get all not translated words; 3=get all requests
        $Self->{Debug} = 0;

        my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
        my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');
        my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');

        $Self->{Home}         = $ConfigObject->Get('Home') . '/';
        $Self->{DefaultTheme} = $ConfigObject->Get('DefaultTheme');
        $Self->{UsedWords}    = {};
        $Self->{UsedInJS}     = {};

        $Self->{LanguageFiles} = [];
        $Self->{Translation} = {};

        my $LanguageFile = "Kernel::Language::$Self->{UserLanguage}";

        # load text catalog ...
        if ( !$MainObject->Require($LanguageFile) ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Sorry, can't locate or load $LanguageFile "
                    . "translation! Check the Kernel/Language/$Self->{UserLanguage}.pm (perl -cw)!",
            );
        }
        else {
            push @{ $Self->{LanguageFiles} }, "$Self->{Home}/Kernel/Language/$Self->{UserLanguage}.pm";
        }

        my $LanguageFileDataMethod = $LanguageFile->can('Data');

        # Execute translation map by calling language file data method via reference.
        if ($LanguageFileDataMethod) {
            if ( $LanguageFileDataMethod->($Self) ) {

                # Debug info.
                if ( $Self->{Debug} > 0 ) {
                    $LogObject->Log(
                        Priority => 'debug',
                        Message  => "Kernel::Language::$Self->{UserLanguage} load ... done.",
                    );
                }
            }
        }
        else {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Sorry, can't load $LanguageFile! Check if it provides Data method",
            );
        }

        # load action text catalog ...
        my $CustomTranslationModule = '';
        my $CustomTranslationFile   = '';

        # load the package translation file
        my @Files = [ 'Kernel/Language/' . $Self->{UserLanguage} . '_' ."$Self->{package}.pm" ];
        
        FILE:
        for my $File (@Files) {
            # next if file does not exist
            next FILE if !-f $File;

            # get module name based on file name
            my $Module = $File =~ s/^$Self->{Home}(.*)\.pm$/$1/rg;
            $Module =~ s/\/\//\//g;
            $Module =~ s/\//::/g;

            # Do we have a toplevel language without country code?
            if ( length $Self->{UserLanguage} == 2 ) {

                # Ignore sub-language translation files like (en_GB, en_CA, ...).
                #
                # This will not work for sr_Cyrl and sr_Latn, but in this case there is no "parent"
                #   language where this could be problematic.
                next FILE if $Module =~ /^Kernel::Language::[a-z]{2}_[A-Z]{2}$/;    # en_GB
                next FILE if $Module =~ /^Kernel::Language::[a-z]{2}_[A-Z]{2}_/;    # en_GB_ITSM*
            }

            # Remember custom files to load at the end.
            if ( $Module =~ /_Custom$/ ) {
                $CustomTranslationModule = $Module;
                $CustomTranslationFile   = $File;
                next FILE;
            }

            # load translation module
            if ( !$MainObject->Require($Module) ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Sorry, can't load $Module! Check the $File (perl -cw)!",
                );
                next FILE;
            }
            else {
                push @{ $Self->{LanguageFiles} }, $File;
            }

            my $ModuleDataMethod = $Module->can('Data');

            if ( !$ModuleDataMethod ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Sorry, can't load $Module! Check if it provides Data method.",
                );
                next FILE;
            }

            # Execute translation map by calling module data method via reference.
            if ( eval { $ModuleDataMethod->($Self) } ) {

                # debug info
                if ( $Self->{Debug} > 0 ) {
                    $LogObject->Log(
                        Priority => 'debug',
                        Message  => "$Module load ... done.",
                    );
                }
            }
        }

        # load custom text catalog ...
        if ( $CustomTranslationModule && $MainObject->Require($CustomTranslationModule) ) {

            push @{ $Self->{LanguageFiles} }, $CustomTranslationFile;

            my $CustomTranslationDataMethod = $CustomTranslationModule->can('Data');

            # Execute translation map by calling custom module data method via reference.
            if ($CustomTranslationDataMethod) {
                if ( eval { $CustomTranslationDataMethod->($Self) } ) {

                    # Debug info.
                    if ( $Self->{Debug} > 0 ) {
                        $LogObject->Log(
                            Priority => 'Debug',
                            Message  => "$CustomTranslationModule load ... done.",
                        );
                    }
                }
            }
            else {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Sorry, can't load $CustomTranslationModule! Check if it provides Data method.",
                );
            }
        }
    }
};

sub Translate {
    my ( $Self, $Text, @Parameters ) = @_;

    my $orgText //= '';

    $Text = $Self->{Translation}->{$orgText} || $orgText;

    if ($orgText eq $Text) {
        # no translation found
        # write untranslated text to target file
        my $TargetFile = $Self->{Home} . 'Kernel/Language/' . $Self->{UserLanguage} . '_' . $Self->{package} . '.pm';
        open my $FH, '>>', $Self->{target} or die $!;
        print $FH "\$Self->{Translation}->{'$Text'} = '$Text';\n";
        close $FH;
    }

    return $Text if !@Parameters;

    for my $Count ( 0 .. $#Parameters ) {
        return $Text if !defined $Parameters[$Count];
        $Text =~ s/\%(s|d)/$Parameters[$Count]/;
    }

    return $Text;
}


1;