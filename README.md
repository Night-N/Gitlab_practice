# Gitlab. Practice. 1

## Tasks
- Setup selfhosted gitlab  in cloud with container registry

## Contents
- [Part 1. Creating VM with docker](#Part-1)</br>
VM in yandex cloud with docker via Terraform
- [Part 2. Gitlab and Gitlab runner in container](#Part-2)  
- [Part 3. Docker registry](#Part-3)  

## Part 1
- Server is made with Terraform, docker is installed by passing configs to cloud-init.
  - Linux image: Ubuntu 20.04 LTS
  - [main.tf](./main.tf) 
  - [metadata.yaml](./metadata.yaml)
<details>
<summary>main.tf</summary>

```
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

data "template_file" "metadata" {
  template = file("./metadata.yaml")
}

provider "yandex" {
  token = "${var.yc_token}"
  cloud_id  = "b1ggel59310trksk1fu4"
  folder_id = "b1g9oing6niujio3j61t"
  zone      = "ru-central1-a"
}

resource "yandex_compute_instance" "gitlab" {
  name = "gitlab"
  platform_id = "standard-v3"
  allow_stopping_for_update = true
  resources {
    core_fraction = 50
    cores  = 2
    memory = 8
  }

  boot_disk {
    initialize_params {
      image_id = "fd84n8eontaojc77hp0u"
      size = 20
      type = "network-ssd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }
  
  metadata = {
    user-data = data.template_file.metadata.rendered
  }

  scheduling_policy {
    preemptible = true
  }
}
resource "yandex_vpc_network" "network-2" {
  name = "network2"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-2.id
  v4_cidr_blocks = ["192.168.1.0/24"]
}

output "external_ip_address_gilab" {
  value = yandex_compute_instance.gitlab.network_interface.0.nat_ip_address
}
```

</details>

Installation of docker is automated with terraform:

<details> 
  <summary>Metadata.yaml </summary>

```
#cloud-config
users:
  - name: night
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh-authorized-keys:
      - ${file("./yc-terraform.pub")}
timezone: Europe/Moscow
package_update: true
package_upgrade: true
packages:
  - curl
  - openssh-server
  - ca-certificates
  - gnupg
apt:
  sources:
    docker:
      source: "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
      keyid: "9DC858229FC7DD38854AE2D88D81803C0EBFCD88"
package_update: true
packages:
  - docker-ce 
  - docker-ce-cli 
  - containerd.io 
  - docker-buildx-plugin 
  - docker-compose-plugin
```
</details>



## Part 2



- Gitlab runs in docker container, IP address is passed as a hostname
- For testing purposes instance is run on simple http, with no TLS
```
export GITLAB_HOME=/srv/gitlab
sudo docker run --detach --hostname [ip_address] --publish 80:80 --name gitlab --restart always  --volume $GITLAB_HOME/config:/etc/gitlab  --volume $GITLAB_HOME/logs:/var/log/gitlab --volume $GITLAB_HOME/data:/var/opt/gitlab --shm-size 256m gitlab/gitlab-ce:latest
```
Obtaining initial password:
```
sudo docker exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password
```
Starting runner:
```
docker run --privileged -d --name gitlab-runner --restart always -v /srv/gitlab-runner/config:/etc/gitlab-runner -v /var/run/docker.sock:/var/run/docker.sock gitlab/gitlab-runner:latest
```
Registering runner
```
docker run --rm -it -v /srv/gitlab-runner/config:/etc/gitlab-runner gitlab/gitlab-runner register
```

In case IP changed:
in ../gitlab/config/gitlab.rb add text:
```
external_url 'http://example/'
```
and then run 
```
gitlab-ctl reconfigure
```

In case password forgotten:
```
docker exec -it gitlab gitlab-rake "gitlab:password:reset[root]"
```


- There are 2 ways to make docker images
  - First one is we can mount docker.sock "/var/run/docker.sock:/var/run/docker.sock" and use docker:version. </br>
  - Second one is to use docker:version-dind as a service inside docker container, which isolates it from docker daemon on host machine

starting from 19.03 dind creates certs and requires them for communication:</br>
https://about.gitlab.com/blog/2019/07/31/docker-in-docker-with-docker-19-dot-03/


Final configuration for runner.
config.toml 
```
concurrent = 1
check_interval = 0
shutdown_timeout = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "runner1"
  url = "url"
  id = 2
  token = "token"
  executor = "docker"
  [runners.feature_flags]
    FF_NETWORK_PER_BUILD = true
  [runners.cache]
    MaxUploadedArchiveSize = 0
  [runners.docker]
    tls_verify = false
    image = "docker:24.0.2"
    privileged = true
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/certs/client", "/cache"]
    shm_size = 0
```
![](./img/task2.jpg)
## Part 3 

Docker registry. Volume is mounted on host machine to preserve images built by gitlab

```
docker run -d --restart always -p 5000:5000 -v  /srv/gitlab/data/registry_data:/var/lib/registry/ --name registry registry:2
```

Adjustments in gitlab  ../config/gitlab.rb  to connect it to registry

```
registry_external_url 'http://[ip_address]:5000'
gitlab_rails['registry_enabled'] = true
gitlab_rails['registry_host'] = "localhost"
gitlab_rails['registry_port'] = "5000"
gitlab_rails['registry_path'] = "/var/opt/gitlab/registry_data/docker/registry"
registry['enable'] = true
gitlab_rails['registry_api_url'] = "http://[ip_address]:5000"
```
![](./img/task3.jpg)