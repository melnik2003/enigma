# [Enigma]

## Overview
Enigma is a simple encryption-decryption script designed for secure archiving on GNU+Linux systems. With a focus on user-friendly functionality and robust cryptographic standards, this tool ensures that your data remains protected and somewhat obfuscated. It may be hard to understand how it works at first, but the logic is pretty straightforward.

- Script for secure and simple operations related to archiving, encryption, decryption and obfuscation
- It requires tar, gpg, wipe, tree
- The script works in semi-automatic mode, gpg interface handles some  of the actions like writing passwords.
- I recommend using the script with password managers
- Also I recommend you to initialize the main directory using -i, it will help reduce the damage you could do to the system in case you pass wrong file paths to the script
- The main directory is not supposed to store files

## Features
- **Secure Encryption**: Protect your files with gpg encryption.
- **Effortless Decryption**: Easily decrypt archives when needed.
- **Customizable Options**: Set cli options to suit your requirements.
- **Lightweight**: Minimal resource usage for efficient performance.

## Installation
### Requirements
- tar
- gpg
- wipe
- tree

### Steps
1. Clone this repository
	```bash
	git clone https://github.com/yourusername/enigma.git
	```
2. Navigate to the project directory:
	```bash
	cd enigma
	```
3. Add run permissions to update scirpt
	```bash
	sudo chmod +x update.sh
	```
4. Run update scirpt
	```bash
	./update.sh
	```
5. Initialize internal directories
	```bash
	./enigma.sh -I
	```
6. Install dependencies if needed
	```bash
	sudo apt update
	sudo apt install tar gpg wipe tree
	```
7. Move files inside the input directory

## Examples
### Encrypt files and remove originals
```bash
./enigma.sh -re
```

### Unpack encrypted archive /home/user/archive to /home/user/
```bash
./enigma.sh -d -i /home/user/archive -o /home/user/
```

### Clean temp directory
```bash
./enigma.sh -c temp
```

## Roadmap
- [ ] Add option to change obfuscation extension
- [ ] Add option to change compression level
- [ ] Add integration with a password manager
- [ ] Add license or make up one

## Known issues
- gpg timeout
gpg password window has a timeout, be careful when using with -r option. That's why I added progress bar to the tar command, use it to be prepared

## License
No license

## Acknowledgments
- Me