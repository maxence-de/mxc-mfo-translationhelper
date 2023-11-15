# TranslationHelper for Znuny/Otobo

The TranslationHelper is a utility module for Znuny that aids in managing translations of Znuny modules. It is designed to help identify missing translations for specific packages, making the translation process more efficient and ensuring consistency.

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
- Lightweight and non-intrusive, does not affect Znuny's standard behavior when not in use.

## Getting Started

To use the TranslationHelper, follow these steps:

1. Clone the repository to your Znuny installation.

2. Initialize the TranslationHelper in your module:
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

       $translationHelper->init('YourModule', $exclude);
       # ...
   }
3. Test your module while the TranslationHelper is active to log missing translations.
4. Once your module is ready, remove or comment out the TranslationHelper initialization.

## Exclusion List

The `$exclude` parameter allows you to specify terms that should be excluded from translation suggestions by the TranslationHelper. This is useful for avoiding unnecessary suggestions for terms that are either part of Znuny's core or already being translated in other modules. You can add terms to the exclusion list as needed.

## Note

1. The TranslationHelper is a developer tool and should not affect the end-user experience.
2. Ensure that your module's translation file follows the naming convention based on the currently set language (e.g., de_YourModule.pm).
3. This tool is most effective when used during module development to catch missing translations early.
4. The TranslationHelper is not a replacement for the translation process. It is designed to aid in the translation process by identifying missing translations and suggesting translations for them. It is currently not intended to be used as a translation tool.
5. Look into the source code for detailled documentation.

## Feedback

We welcome your feedback and suggestions for improving the TranslationHelper. Please feel free to create issues or pull requests on GitHub.

TranslationHelper is developed and maintained by maxence business consulting GmbH (https://www.maxence.de/).
