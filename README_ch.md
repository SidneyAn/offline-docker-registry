# 欢迎使用镜像仓库迁移工具
  本项目提供了可快速迁移的镜像仓库生成/运行工具，主要解决在不联网的机器上拉取（有限集合）docker 镜像问题，比如可以用与 starlingx 项目中第一个controller 的不联网部署。 并实现了即插即用，无需花费 load image 的时间。 
## 如何生成一个可迁移的镜像仓库
  只需在可连接docker hub 的机器上，下载本项目并运行下面的命令。
      
      $cd offline-docker-registry
      $sudo ./registry_generator.sh -i platform_images.lst
  其中，platform_images.lst 为需要的镜像列表 （格式参考 sample），其中需要占用5000端口作为临时仓库的端口。
  工具支持指定临时仓库的端口，以及下载容器的第三方镜像仓库，如阿里云等，具体命令如下

     $sudo ./registry_generator.sh -i platform_images.lst -p 5001 -r registry.dcp-dev.intel.com
  脚本运行结束后，会在当前目录下生成一个名为 images 的目录。
## 如何运行可迁移镜像仓库
  将“offline-docker-registry”文件夹（包括上面脚本生成的 images目录）拷贝到未联网的机器上， 运行下面的命令即可。
  
    $cd PATH_OF_isolated-registry
    $sudo sh registry_enabled.sh
   现在我们的可迁移镜像仓库即可通过localhost:5011 访问。可使用下面命令验证

    $curl http://localhost:5011/v2/_catalog
    {"repositories":["adminer","airshipit/armada","airshipit/kubernetes-entrypoint","google-containers/pause","httpd"]}
## 离线部署starlingX controller-0
   将“offline-docker-registry”文件夹（包括脚本生成的 images目录）拷贝到只配置了OAM网络的安装好stx iso 的机器上，运行下面的命令

    cd PATH_OF_isolated-registry
    sudo sh registry_enabled.sh
   参考下面的配置，在 localhost.yml 文件中配置第三方docker 镜像仓库 （[OAM_IP]:5011）:

    docker_registries:
      defaults:
        url: 10.10.10.10:5011
        secure: False
  之后按照正常的部署流程，运行ansible启动脚本并部署启动需要的节点即可。

    ansible-playbook PATH_OF_bootstrap.yml -e "ansible_become_pass=[sysadmin_passwd]"


> 注意:
>  建议在部署完controller-1 之后，做一次host-swact。
