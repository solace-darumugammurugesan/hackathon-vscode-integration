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
            filesToCheck.push(`${x}_${y}.tcl`);
            filesToCheck.push(`${x}.tcl`);
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

        // If the current file is in a sub-directory of 'internalFw'
        if (path.basename(parentDir) == 'internalFw') {
            console.log("File is in internalFw sub-directory");

            // Add 'externalApi' directory to foldersToCheck.
            const parent = path.dirname(parentDir);
            foldersToCheck.push(`${parent}/externalApi`);
            console.log(`externalApi: ${parent}/externalApi`);

            // Get list of all subdirectories in 'internalFw' and add them to foldersToCheck.
            const internalFwSubDirs = fs.readdirSync(parentDir, { withFileTypes: true }).filter(dirent => dirent.isDirectory()).map(dirent => dirent.name);
            foldersToCheck.push(...internalFwSubDirs.map(subdir => path.join(parentDir, subdir)));
            console.log(`internalFwSubDirs: ${internalFwSubDirs}`);
            console.log(`${foldersToCheck}`);
        }
        // If the current file is in the 'externalApi' directory
        else if (path.basename(dir) == 'externalApi'){
            console.log("File is in externalApi directory");
            // Add 'externalApi' directory to foldersToCheck.
            foldersToCheck.push(dir);
            console.log(`externalApi: ${dir}`);

            // Get list of all subdirectories in 'internalFw' and add them to foldersToCheck.
            const internalFwSubDirs = fs.readdirSync(`${parentDir}/internalFw`, { withFileTypes: true }).filter(dirent => dirent.isDirectory()).map(dirent => dirent.name);
            foldersToCheck.push(...internalFwSubDirs.map(subdir => path.join(`${parentDir}/internalFw`, subdir)));
            console.log(`internalFwSubDirs: ${internalFwSubDirs}`);
        }
        // If the current file is in a sub-directory of 'scripts'
        else  if ((path.basename(parentDir) == 'scripts')){
            console.log("File is in scripts sub-directory");
            const parent = path.dirname(parentDir);

            // Add 'externalApi' directory to foldersToCheck.
            foldersToCheck.push(`${parent}/externalApi`);
            console.log(`externalApi: ${parent}/externalApi`);

            // Get list of all subdirectories in 'internalFw' and add them to foldersToCheck.
            const internalFwSubDirs = fs.readdirSync(`${parent}/internalFw`, { withFileTypes: true }).filter(dirent => dirent.isDirectory()).map(dirent => dirent.name);
            foldersToCheck.push(...internalFwSubDirs.map(subdir => path.join(`${parent}/internalFw`, subdir)));
            console.log(`internalFwSubDirs: ${internalFwSubDirs}`);
        }
        // If the current file is in the 'scripts' directory
        else  if ((path.basename(dir) == 'scripts')){
            console.log("File is in scripts directory");
            // Add 'externalApi' directory to foldersToCheck.
            foldersToCheck.push(`${parentDir}/externalApi`);
            console.log(`externalApi: ${parentDir}/externalApi`);

            // Get list of all subdirectories in 'internalFw' and add them to foldersToCheck.
            const internalFwSubDirs = fs.readdirSync(`${parentDir}/internalFw`, { withFileTypes: true }).filter(dirent => dirent.isDirectory()).map(dirent => dirent.name);
            foldersToCheck.push(...internalFwSubDirs.map(subdir => path.join(`${parentDir}/internalFw`, subdir)));
            console.log(`internalFwSubDirs: ${internalFwSubDirs}`);
        }

        // Check for every folder in the foldersToCheck list
        for (const folder of foldersToCheck) {

            // Check for every file in the filesToCheck list
            for (const file of filesToCheck) {

                console.log(file);
                const filePath = path.join(folder, file);
                console.log(filePath);
                console.log("------");

                // If the file exists, find an occurence of 'word' in the file and save + return its position.
                if (fs.existsSync(filePath)) {
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
        }

        // If the file doesn't exist, return null.
        return null;
    }
}

module.exports = {
    activate,
};