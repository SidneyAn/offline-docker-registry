welcome to use isolated-registry
Here we provides a method to fast 'move' an available registry (could support the controller to do previsions off-line) to the controller that didn't be prevised.

how to generate an available registry
We the docker images list required to support the controller prevision is known (e.g. list from an deployed system). Download this folder to you host which connected the internet. Run the generator script

  sudo ./registry_generator.sh -i platform_images.lst
Then there will generate an folder "images" under the current folder. Now we get the registry files with required images.

Advanced options are also supported

  sudo ./registry_generator.sh -i platform_images.lst -p 5001 -r registry.dcp-dev.intel.com
how to enable temp registry for controller prevision
Copy the whole 'isolated-registry' folder with "images" generated above to a host which is accessable for the offilen host by OAM network. Copy it to the offline host bootstraped with stx iso is also supported.

cd PATH_OF_isolated-registry
sudo sh registry_enabled.sh
now there is a docker registry running on [OAM-IP]:5011. And the docker registry info to the ansible config file "localhost.yml" like following:

docker_registries:
  defaults:
    url: 10.10.10.10:5011
    secure: False
run ansible bootstrap playbook again. and it can offline prevision the controller this time.

ansible-playbook PATH_OF_bootstrap.yml -e "ansible_become_pass=[sysadmin_passwd]"
Now you can config the system and deploy other nodes follow the official user guide.

Note: we suggest do a host-swact after controller-1 unlocked. Or you will see error log in sysinv.log if the controller-0 is reboot/shutdown and the controller-1 are first time became the active node. Though the error log did not impact the system functions.
