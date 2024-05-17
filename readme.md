# Econnector installation

This repo is used for econnector installation, currently it only supports windows system.

## Windows
Put all the need files as the structure you want to keep on user's laptop, install script will copy them to `C:\%SERVICE_NAME%` directory.

Modify the `config.bat` file to update the installation config, don't put any special characters or space in the `SERVICE_NAME`, it's use as directory name, the apache common daemon has issue to read such directory name.

Install script will also manage the JVM installation, so we don't need to worry about Java things in the system.
