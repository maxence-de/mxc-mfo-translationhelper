# TranslationHelper for Znuny/Otobo

The TranslationHelper is a utility module for Znuny/Otobo developers that aids in managing translations of Znuny modules. It is designed to help identify missing translations for specific packages, making the translation process more efficient and ensuring consistency.

## License

The project is distributed under the GNU General Public License (GPL v3).

## Features

- Identifies missing translations for specified packages.
- Integrates with Znuny/Otobo's translation files and the translation files of your modules.
- Excludes translations from other modules to avoid accidental omission of translations made by other modules.
- Can be initialized on-demand for specific modules.
- Automatically creates or modifies translation files for modules.
- Supports an exclusion list to prevent unwanted translation suggestions.
- Logs missing translations during development for comprehensive testing.
- Lightweight and non-intrusive, does not affect Znuny/Otobo's standard behavior when not in use.

## Getting Started

To use the TranslationHelper, follow these steps:

1.  Clone the repository to your workspace directory and link the module to your development environment framework.
Alternatively, download the opm file from the mxcPackages directory and install it using the Znuny/Otobo package manager.

2. Initialize the TranslationHelper in your frontend module:
   ```perl
   use MFO::DevTools::Language::TranslationHelper;

   sub new {
       my ( $class, %param ) = @_;
       my $self = $class->SUPER::new(%param);

       my $translationHelper = $Kernel::OM->Get('MFO::DevTools::Language::TranslationHelper');
       my $exclude = [
           'Delete all activities',
           'Delete all',
           # ... Add more exclusions as needed
       ];
      
       # 'YourModule' is the name of your language module. Will be exanded to 'de_YourModule.pm' or 
       # 'en_YourModule.pm' depending on the currently set language.
       $translationHelper->init('YourModule', $exclude); 
       # ...
   }
3. Test your module while the TranslationHelper is active to log missing translations.
4. Once your module is ready, remove or comment out the TranslationHelper initialization.

## Exclusion List

The `$exclude` parameter allows you to specify terms that should be excluded from translation suggestions by the TranslationHelper. This is useful for avoiding unnecessary suggestions for terms that are either part of Znuny's core or already being translated in other modules. You can add terms to the exclusion list as needed.

## Operation

The TranslationHelper will log missing translations during development. You have to click through all the screens of your module to ensure that all translations are logged. The TranslationHelper will not log translations for screens and screen features that are not visited during the test. Do not forget error messages and other messages that are usually not displayed on the screen.
## Output

The TranslationHelper will modify the language module of the first package of the supplied packages. If the module does not exist, it will be created. The TranslationHelper will not modify any other language modules.
Sample output:
```perl

Self->{Translation} = {

        # $$ START TranslationHelper $$
        # 'Change System Phone Number' => 'Change System Phone Number'
        # 'Change System Phone Number' => 'Change System Phone Number'
        # 'Enter Phone Number' => 'Enter Phone Number'
        # 'Select the validity of the phone number.' => 'Select the validity of the phone number.'
        # 'Enter Comment' => 'Enter Comment'
        # 'Enter a comment.' => 'Enter a comment.'
        # $$ END TranslationHelper $$

        %{$Self->{Translation}},
        # AdminSystemPhoneNumber.tt
        "System Phone Number Management" => "Verwaltung von System-Telefonnummern",
        "Add System Phone Number" => "System-Telefonnummer hinzufügen",
        "Edit System Phone Number" => "System-Telefonnummer bearbeiten",
        "This field is required and needs to be a valid phone number." => "Dieses Feld ist erforderlich und muss eine gültige Telefonnummer sein.",
        "This phone number cannot be set to invalid, because it is used in one or more queue(s) or auto response(s)." => "Diese Telefonnummer kann nicht auf ungültig gesetzt werden, da sie in einer oder mehreren Queue(s) oder Auto Response(s) verwendet wird.",
        "Enable phone number checking." => "Telefonnummernprüfung aktivieren.",
    };
```
Move the the output from the TranslationHelper section to the translation list below, translate the terms and remove the comment.

## Note

1. The TranslationHelper is a developer tool and should not affect the end-user experience.
2. Ensure that your module's translation file follows the naming convention based on the currently set language (e.g., de_YourModule.pm).
3. This tool is most effective when used during module development to catch missing translations early.
4. The TranslationHelper is not a replacement for the translation process. It is designed to aid in the translation process by identifying missing translations and suggesting translations for them. It is currently not intended to be used as a translation tool.
5. See mxcPackages directory for opm files.
5. Look into the source code for detailled documentation.

## Feedback

We welcome your feedback and suggestions for improving the TranslationHelper. Please feel free to create issues or pull requests on GitHub.

TranslationHelper is developed and maintained by maxence business consulting GmbH (https://www.maxence.de/).
