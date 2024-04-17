const vscode = require('vscode');
const path = require('path');
const fs = require('fs');

function activate(context) {
    context.subscriptions.push(vscode.languages.registerDefinitionProvider('tcl', new TclDefinitionProvider()));
}

class TclDefinitionProvider {
    provideDefinition(document, position, token) {
        console.log(position);
        console.log("------");
        const wordRange = document.getWordRangeAtPosition(position);
        const word = document.getText(wordRange);

        console.log(wordRange);
        console.log("------");
        console.log(word);
        console.log("------");
        // Extract the method name from the word.
        const methodName = word.split('::').pop();
        console.log(methodName);
        console.log("------");
        // Look for a file with the same name as the method in the same directory as the current document.
        const dir = path.dirname(document.uri.fsPath);
        console.log(dir);
        console.log("------");

        const filePath = path.join(dir, `${methodName}.tcl`);
        console.log(filePath);
        console.log("------");
        // If the file exists, return a Location pointing to the start of this file.
        if (fs.existsSync(filePath)) {
            const uri = vscode.Uri.file(filePath);
            const position = new vscode.Position(0, 0);
            return new vscode.Location(uri, position);
        }

        // If the file doesn't exist, return null.
        return null;
    }
}

module.exports = {
    activate,
};