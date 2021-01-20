## Learning Terraform / Azure

* provider.tf = Responsável por definir a plataforma como Azure como provedor
* resource_group.tf = Para o Azure, precisa-se criar um resource group com a vm, network, vn etc
* terraform plain = Faz diff do conteúdo local com da nuvem
* terraform apply = Aplica as mudanças
* az login = fazer login na azure
* O arquivo terraform.tfstate é responsável por guardar o que está na nuvem com de -> para (não mexer ou versionar)
* vnet = Virtual Network, criar referenciando o resource_group.name, mesma coisa para subnet
* terraform show = monstra o que está na nuvem
* terraform destroy = deleta tudo
* terraform state show recurso
* data something = Usado para acessar informações sobre o ip público. Necessário setar para null-resources
* terraform vars:
    - permite criação de variaveis
    - terraform output <VARNAME> : print variavel
    - Setar a variaveis para subir: terraform apply-<VARNAME>=VALUE ou com variaveis de ambiente
    - Possível setar default: variable "teste" {type string default "123"}
* terraform taint null_resource.upload = recriar um recurso
