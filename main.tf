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