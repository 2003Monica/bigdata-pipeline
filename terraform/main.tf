terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.5"
    }
  }
}

provider "docker" {}

resource "docker_network" "hadoop_network" {
  name = "hadoop-network"
}

resource "docker_image" "namenode" {
  name         = "bde2020/hadoop-namenode:2.0.0-hadoop3.2.1-java8"
  keep_locally = true
}

resource "docker_image" "datanode" {
  name         = "bde2020/hadoop-datanode:2.0.0-hadoop3.2.1-java8"
  keep_locally = true
}

resource "docker_image" "resourcemanager" {
  name         = "bde2020/hadoop-resourcemanager:2.0.0-hadoop3.2.1-java8"
  keep_locally = true
}

resource "docker_image" "nodemanager" {
  name         = "bde2020/hadoop-nodemanager:2.0.0-hadoop3.2.1-java8"
  keep_locally = true
}

resource "docker_image" "historyserver" {
  name         = "bde2020/hadoop-historyserver:2.0.0-hadoop3.2.1-java8"
  keep_locally = true
}

locals {
  hadoop_environment = [
    "CORE_CONF_fs_defaultFS=hdfs://namenode:9000",
    "HDFS_CONF_dfs_replication=1",
    "HDFS_CONF_dfs_permissions_enabled=false",
    "YARN_CONF_yarn_resourcemanager_hostname=resourcemanager",
    "YARN_CONF_yarn_nodemanager_aux___services=mapreduce_shuffle",
    "MAPRED_CONF_mapreduce_framework_name=yarn"
  ]
}

resource "docker_container" "namenode" {
  name    = "namenode"
  image   = docker_image.namenode.image_id
  restart = "unless-stopped"

  env = concat(local.hadoop_environment, [
    "CLUSTER_NAME=bigdata-cluster"
  ])

  networks_advanced {
    name = docker_network.hadoop_network.name
  }

  ports {
    internal = 9870
    external = 9870
  }
}

resource "docker_container" "datanode" {
  name    = "datanode"
  image   = docker_image.datanode.image_id
  restart = "unless-stopped"

  env = concat(local.hadoop_environment, [
    "SERVICE_PRECONDITION=namenode:9870"
  ])

  networks_advanced {
    name = docker_network.hadoop_network.name
  }

  depends_on = [docker_container.namenode]
}

resource "docker_container" "resourcemanager" {
  name    = "resourcemanager"
  image   = docker_image.resourcemanager.image_id
  restart = "unless-stopped"

  env = concat(local.hadoop_environment, [
    "SERVICE_PRECONDITION=namenode:9870 datanode:9864"
  ])

  networks_advanced {
    name = docker_network.hadoop_network.name
  }

  ports {
    internal = 8088
    external = 8088
  }

  depends_on = [
    docker_container.namenode,
    docker_container.datanode
  ]
}

resource "docker_container" "nodemanager" {
  name    = "nodemanager"
  image   = docker_image.nodemanager.image_id
  restart = "unless-stopped"

  env = concat(local.hadoop_environment, [
    "SERVICE_PRECONDITION=resourcemanager:8088"
  ])

  networks_advanced {
    name = docker_network.hadoop_network.name
  }

  depends_on = [docker_container.resourcemanager]
}

resource "docker_container" "historyserver" {
  name    = "historyserver"
  image   = docker_image.historyserver.image_id
  restart = "unless-stopped"

  env = concat(local.hadoop_environment, [
    "SERVICE_PRECONDITION=resourcemanager:8088"
  ])

  networks_advanced {
    name = docker_network.hadoop_network.name
  }

  ports {
    internal = 8188
    external = 8188
  }

  depends_on = [docker_container.resourcemanager]
}
resource "docker_image" "hive" {
  name         = "bde2020/hive:2.3.2-postgresql-metastore"
  keep_locally = true
}

resource "docker_image" "hive_postgres" {
  name         = "bde2020/hive-metastore-postgresql:2.3.0"
  keep_locally = true
}

resource "docker_container" "hive_postgres" {
  name    = "hive-metastore-postgresql"
  image   = docker_image.hive_postgres.image_id
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.hadoop_network.name
  }
}

resource "docker_container" "hive_metastore" {
  name    = "hive-metastore"
  image   = docker_image.hive.image_id
  restart = "unless-stopped"

  command = [
    "/opt/hive/bin/hive",
    "--service",
    "metastore"
  ]

  env = concat(local.hadoop_environment, [
    "SERVICE_PRECONDITION=namenode:9870 hive-metastore-postgresql:5432",
    "HIVE_SITE_CONF_javax_jdo_option_ConnectionURL=jdbc:postgresql://hive-metastore-postgresql/metastore",
    "HIVE_SITE_CONF_javax_jdo_option_ConnectionDriverName=org.postgresql.Driver",
    "HIVE_SITE_CONF_javax_jdo_option_ConnectionUserName=hive",
    "HIVE_SITE_CONF_javax_jdo_option_ConnectionPassword=hive"
  ])

  networks_advanced {
    name = docker_network.hadoop_network.name
  }

  ports {
    internal = 9083
    external = 9083
  }

  depends_on = [
    docker_container.namenode,
    docker_container.hive_postgres
  ]
}

resource "docker_container" "hive_server" {
  name    = "hive-server"
  image   = docker_image.hive.image_id
  restart = "unless-stopped"

  env = concat(local.hadoop_environment, [
    "SERVICE_PRECONDITION=hive-metastore:9083",
    "HIVE_SITE_CONF_javax_jdo_option_ConnectionURL=jdbc:postgresql://hive-metastore-postgresql/metastore",
    "HIVE_SITE_CONF_javax_jdo_option_ConnectionDriverName=org.postgresql.Driver",
    "HIVE_SITE_CONF_javax_jdo_option_ConnectionUserName=hive",
    "HIVE_SITE_CONF_javax_jdo_option_ConnectionPassword=hive"
  ])

  networks_advanced {
    name = docker_network.hadoop_network.name
  }

  ports {
    internal = 10000
    external = 10000
  }

  depends_on = [docker_container.hive_metastore]
}