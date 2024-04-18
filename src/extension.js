const vscode = require('vscode');
const path = require('path');
const fs = require('fs');

function activate(context) {
    context.subscriptions.push(vscode.languages.registerDefinitionProvider('tcl', new TclDefinitionProvider()));
}

class TclDefinitionProvider {
    provideDefinition(document, position, token) {
        // Get the word at the current position.
        const wordRange = document.getWordRangeAtPosition(position, /::\w+(::\w+)*(::\w+)?/);
        const word = document.getText(wordRange);

        // Split the word into parts.
        const parts = word.split('::').filter(Boolean);
        const [x, y, z] = parts;

        console.log("------");
        console.log("word:");
        console.log(word);

        console.log(`x: ${x}`);
        console.log(`y: ${y}`);
        console.log(`z: ${z}`);
        console.log(`${parts.length}`);

        const filesToCheck = [];
        const foldersToCheck = [];

        // If there is only 1 part, the part is the method. 
        if (parts.length === 1) {
            filesToCheck.push(`${x}.tcl`);
        }
        // If there are 2 parts, the first part is the namespace and the second part is the method.
        else if (parts.length === 2) {
            //filesToCheck.push(`${x}.tcl`);
            filesToCheck.push(`${x}_${y}.tcl`);
        }
        // If there are 3 parts, the first part is the namespace, the second part is the class, and the third part is the method.
        else if (parts.length === 3) {
            filesToCheck.push(`${x}_${y}.tcl`);
            filesToCheck.push(`${x}.tcl`);
        }



        // Get current file directory and print it.
        const dir = path.dirname(document.fileName);
        console.log(dir);

        // Get the current files parent directory and print it.
        const parentDir = path.dirname(dir);
        console.log(parentDir);

        // For every file in filesToCheck
        for (const file of filesToCheck) {
            console.log(file);
            const filePath = path.join(dir, file);
            console.log(filePath);
            console.log("------");

            if (fs.existsSync(filePath)) {

                // If the file exists, find an occurence of 'word' in the file and save its position.
                const fileContent = fs.readFileSync(filePath, 'utf8');
                const regex = new RegExp(word, 'g');
                const match = regex.exec(fileContent);
                if (match) {
                    const line = fileContent.substring(0, match.index).split('\n').length - 1;
                    const position = new vscode.Position(line, match.index);
                    return new vscode.Location(vscode.Uri.file(filePath), position);
                }
            }
        }

        // If the file doesn't exist, return null.
        return null;
    }
}

module.exports = {
    activate,
};