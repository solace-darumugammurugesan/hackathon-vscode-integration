# AFW VSCode Integration
AFW TCL Support for Visual Studio Code

## Description
A Visual Studio Code Extension for AFW Scripts.

Currently, we are using Sublime Text for AFW scripts, but with the introduction of GitHub CoPilot it would be beneficial to switch to Visual Studio Code. The extension we created includes:
- TCL Solace Syntax
- Custom TCL AFW Snippets
- GoTo Method Definitions
- Peek Method Definitions

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [Contact](#contact)
- [References](#references)

## Installation

1. Download the .vsix file from the GitHub Repo
2. Go to VSCode and click on the Extensions Tab
3. Click the three dots on the top right of the Extensions Menu and hit "Install from VSIX"
4. Choose the .vsix file you downloaded - The extension will automatically install 
5. SSH into your devserver from VSCode or mount your AFW Folder to the VSCode workspace 

## Usage

1. Snippets: Autocomplete dropdown option when typing code
2. Syntax: Confirm Tcl (Solace) is displayed in the bottom right of VSCode
3. GoTo Definition: Highlight an AFW method and press F12 
4. Peek - Overlay of an AFW Method: Hightlight an AFW Method and press Command/Ctrl + F12

## Contact

- @Deepanraj A M (deepanraj.arumugammurugesan@solace.com)
- @Gabriel Levesque (gabriel.levesque@solace.com)
- @Asad Waheed (asad.waheed@solace.com)

## References

1. Referred to the following GitHub Repo: https://github.com/bitwisecook/vscode-tcl?tab=readme-ov-file
2. Solace TCL Files: https://vault.internal.soltest.net/public/sublime


