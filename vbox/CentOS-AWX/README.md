# vagrant-AWX
Vagrant setup for AWX

### Prerequisites

* [Vagrant](https://www.vagrantup.com/intro/getting-started/install.html) - Vagrant manages virtual machines 
* [Virtualbox](https://www.virtualbox.org/wiki/Linux_Downloads) - Vagrant depends on virtualbox to run virtual machines 

### Installing

First install vagrant and virtualbox on your machine. 

After installing vagrant, just clone this github repo.

```
git clone https://github.com/krivegasa/vagrant-boxes.git
cd vagrant-boxes/vbox/CentOS-AWX/
vagrant up
```

vagrant up command will download precise64 box which is ubuntu machine and run provision.sh file to install and configure prometheus & grafana into the virtual machine. 

After successful installation, you can visit urls on your host os which are mentioned below to see AWX

```
AWX - http://localhost:8080/
```

If you want to edit any configuration in virtual machine then you can do ssh via following command from the same git directory.You will get remote shell of ubuntu virtual machine from host os.

```
vagrant ssh
```

Default username **admin**
Default password **password**

