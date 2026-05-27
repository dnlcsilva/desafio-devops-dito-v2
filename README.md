# Desafio DevOps II - Dito

Solução DevOps para provisionar e entregar uma API interna em Kubernetes, usando Terraform, Amazon EKS, RDS PostgreSQL, ECR, AWS Secrets Manager, External Secrets Operator, ArgoCD e GitHub Actions.

---

# Arquitetura da solução

- AWS como cloud provider
- Kubernetes gerenciado com Amazon EKS
- Infraestrutura como código com Terraform
- GitOps com ArgoCD
- CI/CD com GitHub Actions
- Secrets centralizados no AWS Secrets Manager
- External Secrets Operator para sincronização com Kubernetes
- IRSA para acesso seguro aos secrets sem access key fixa
- Kustomize para separação de ambientes

---

# Estrutura do projeto

```text
.
├── .github/workflows/
├── app/
├── iac/
│   ├── backend/bootstrap/
│   ├── envs/
│   │   ├── staging/
│   │   └── production/
│   └── modules/
├── manifests/
│   ├── argocd/
│   ├── base/
│   └── overlays/
├── .gitignore
└── README.md
```

---

# Como rodar o projeto localmente

## Pré-requisitos

- Terraform >= 1.6
- Docker
- kubectl
- AWS CLI (somente se quiser aplicar em uma conta AWS real)
- kubeconform

---

## Validar Terraform

### Staging

```bash
cd iac/envs/staging

terraform init -backend=false

terraform fmt -recursive -check ../../

terraform validate
```

### Production

```bash
cd iac/envs/production

terraform init -backend=false

terraform fmt -recursive -check ../../

terraform validate
```

---

## Validar manifests Kubernetes

### Renderização Kustomize

```bash
kubectl kustomize manifests/overlays/staging

kubectl kustomize manifests/overlays/production
```

## Validação estrutural com kubeconform

```bash
kubectl kustomize manifests/overlays/staging > rendered-staging.yaml

kubeconform \
  -strict \
  -summary \
  -ignore-missing-schemas \
  rendered-staging.yaml
```

```bash
kubectl kustomize manifests/overlays/production > rendered-production.yaml

kubeconform \
  -strict \
  -summary \
  -ignore-missing-schemas \
  rendered-production.yaml
```

> Observação: `-ignore-missing-schemas` é usado porque `ExternalSecret` e `SecretStore` são CRDs do External Secrets Operator, e não recursos nativos do Kubernetes.

### Dry-run local

O `kubectl apply --dry-run=client` pode tentar consultar a API do cluster mesmo com `--validate=false`. Por isso, em ambiente local sem cluster Kubernetes configurado, a validação recomendada é usar `kubectl kustomize` + `kubeconform`.

Se houvesse um cluster/kubeconfig válido, podia usar:

```bash
kubectl apply --dry-run=client --validate=false -f rendered-staging.yaml
```

```bash
kubectl apply --dry-run=client --validate=false -f rendered-production.yaml
```

---

## Build local da aplicação

```bash
docker build -t dito-api:local ./app

docker run --rm -p 8080:8080 dito-api:local
```

Teste:

```bash
curl http://localhost:8080/health
```

```bash
curl http://localhost:8080
```

---

# Principais decisões técnicas

Esta seção descreve as decisões tomadas, incluindo alternativas possíveis e o motivo da escolha.

---

## 1. AWS como cloud provider

### Decisão

Escolhi AWS como cloud provider principal.

### Alternativas possíveis

- GCP com GKE, Cloud SQL, Artifact Registry e Secret Manager
- Azure com AKS, Azure Database for PostgreSQL, ACR e Key Vault
- AWS com EKS, RDS, ECR e Secrets Manager

### Motivo da escolha

Apesar do ambiente interno da Dito ser majoritariamente GCP, o desafio permitia qualquer cloud provider. Escolhi AWS porque tenho mais experiência prática com EKS, RDS, ECR, IAM, Secrets Manager e Terraform.

Essa escolha permite demonstrar melhor:

- Kubernetes gerenciado com EKS
- IAM com menor privilégio
- IRSA/OIDC
- registry privado com ECR
- banco gerenciado com RDS
- secrets centralizados com AWS Secrets Manager
- remote state com S3 + DynamoDB

---

## 2. EKS em vez de Kubernetes autogerenciado

### Decisão

Usei Amazon EKS como cluster Kubernetes gerenciado.

### Alternativas possíveis

- Kubernetes autogerenciado com kubeadm
- Kubernetes em bare metal
- ECS/Fargate
- EKS
- GKE/AKS

### Motivo da escolha

O desafio solicitava Kubernetes. O EKS reduz o esforço operacional do control plane e permite integração nativa com IAM, OIDC, VPC, CloudWatch, ECR e add-ons gerenciados.

Eu evitaria Kubernetes autogerenciado nesse cenário inicial porque aumentaria a complexidade operacional sem necessidade para uma API interna simples.

---

## 3. Nodes em subnets privadas

### Decisão

Os nodes do EKS e o RDS foram planejados para rodar em subnets privadas.

### Alternativas possíveis

- Nodes em subnets públicas
- Nodes em subnets privadas com NAT Gateway
- Cluster privado sem endpoint público

### Motivo da escolha

Para reduzir exposição, os workloads ficam em subnets privadas. O NAT Gateway permite saída para internet sem permitir acesso direto de entrada aos nodes.

Mantive o endpoint do EKS público e privado no desenho por simplicidade do desafio, mas em produção real avaliaria restringir o endpoint público por CIDR ou usar acesso apenas privado via VPN/bastion.

---

## 4. Terraform modular em vez de código monolítico

### Decisão

Separei a infraestrutura em módulos:

- `vpc`
- `eks`
- `rds`
- `ecr`
- `iam`
- `secrets`

### Alternativas possíveis

- Um único `main.tf` com todos os recursos
- Módulos públicos prontos da comunidade
- Módulos internos próprios

### Motivo da escolha

Optei por módulos próprios para demonstrar entendimento dos recursos criados e das dependências entre eles.

A modularização facilita:

- manutenção
- reuso
- revisão em Pull Request
- separação de responsabilidades
- evolução da infraestrutura

Em um ambiente real, eu avaliaria usar módulos internos versionados ou módulos públicos consolidados, dependendo do padrão da empresa.

---

## 5. Separação por ambiente com diretórios

### Decisão

Criei diretórios separados para:

- `iac/envs/staging`
- `iac/envs/production`

### Alternativas possíveis

- Workspaces do Terraform
- Branches separadas por ambiente
- Diretórios separados por ambiente
- Repositórios separados

### Motivo da escolha

Escolhi diretórios separados porque deixam explícito o que pertence a cada ambiente. Isso facilita revisão, auditoria e evita aplicar acidentalmente variáveis de production em staging.

Workspaces são úteis em alguns cenários, mas podem esconder diferenças importantes entre ambientes. Para esse desafio, diretórios deixam a estrutura mais clara.

---

## 6. Remote state com S3 + DynamoDB

### Decisão

Configurei backend remoto com S3 e DynamoDB.

### Alternativas possíveis

- State local
- Terraform Cloud
- S3 + DynamoDB
- Backend remoto equivalente em outro provider

### Motivo da escolha

State local não é adequado para trabalho em equipe ou pipeline. O S3 centraliza o state e o DynamoDB evita concorrência com state lock.

Mesmo que o backend não seja aplicado de verdade no desafio, deixei a configuração pronta para demonstrar a prática correta.

---

## 7. RDS PostgreSQL em vez de Postgres dentro do Kubernetes

### Decisão

Usei Amazon RDS PostgreSQL.

### Alternativas possíveis

- Postgres rodando dentro do Kubernetes
- RDS PostgreSQL
- Cloud SQL PostgreSQL
- Aurora PostgreSQL

### Motivo da escolha

Para uma API interna, um banco gerenciado reduz esforço operacional com backup, patching, storage, disponibilidade e recuperação.

Rodar Postgres dentro do Kubernetes exigiria mais cuidado com storage, backup, restore, upgrades e operação stateful. Para o escopo do desafio, RDS é mais adequado.

---

## 8. AWS Secrets Manager + External Secrets Operator

### Decisão

Usei AWS Secrets Manager como fonte de verdade dos secrets e External Secrets Operator para sincronizar com Kubernetes.

### Alternativas possíveis

- Kubernetes Secret puro
- SOPS + Git
- Sealed Secrets
- HashiCorp Vault
- AWS Secrets Manager + External Secrets

### Motivo da escolha

Kubernetes Secret puro não resolve bem gestão centralizada de segredos. Também não queria deixar secrets versionados diretamente no Git.

O Secrets Manager centraliza os dados sensíveis e o External Secrets Operator faz a ponte segura com Kubernetes.

Fluxo:

```text
AWS Secrets Manager
        ↓
External Secrets Operator
        ↓
Kubernetes Secret
        ↓
Pod
```

---

## 9. IRSA em vez de access key no container

### Decisão

Usei IRSA para o workload acessar o AWS Secrets Manager.

### Alternativas possíveis

- Access key em variável de ambiente
- Secret com access key no Kubernetes
- IAM Role no node
- IRSA por ServiceAccount

### Motivo da escolha

Access key fixa aumenta risco de vazamento e rotação manual. IAM Role no node dá permissões mais amplas para todos os Pods daquele node.

Com IRSA, apenas o ServiceAccount da aplicação recebe a permissão necessária. Isso aplica menor privilégio e reduz o impacto em caso de comprometimento.

---

## 10. ECR como registry

### Decisão

Usei Amazon ECR para armazenar as imagens Docker.

### Alternativas possíveis

- Docker Hub
- GitHub Container Registry
- Harbor
- Amazon ECR

### Motivo da escolha

ECR integra nativamente com IAM, EKS e GitHub Actions via OIDC. Também permite scan on push e lifecycle policy para controle de imagens antigas.

Para uma stack AWS, ECR reduz complexidade de autenticação e governança.

---

## 11. Kustomize em vez de Helm

### Decisão

Usei Kustomize para organizar manifests Kubernetes.

### Alternativas possíveis

- YAML duplicado por ambiente
- Helm Chart
- Kustomize
- Jsonnet

### Motivo da escolha

A aplicação do desafio é simples. Kustomize permite manter uma base comum e aplicar apenas diferenças por ambiente, sem criar complexidade extra de templates Helm.

Estrutura usada:

```text
manifests/base
manifests/overlays/staging
manifests/overlays/production
```

Isso reduz duplicação e facilita revisão em Pull Request.

---

## 12. ArgoCD para GitOps

### Decisão

Usei ArgoCD para GitOps.

### Alternativas possíveis

- Deploy direto pela pipeline
- FluxCD
- ArgoCD
- kubectl apply manual

### Motivo da escolha

GitOps mantém o Git como fonte da verdade. A pipeline não precisa aplicar diretamente no cluster; ela atualiza o repositório e o ArgoCD sincroniza o estado desejado.

Escolhi ArgoCD por ser muito utilizado no mercado, já trabalho com ele, ter boa interface visual e permitir sincronização automática ou manual por aplicação.

---

## 13. Staging automático e production manual

### Decisão

Configurei staging com sincronização automática e production com sincronização manual/aprovação.

### Alternativas possíveis

- Tudo automático
- Tudo manual
- Staging automático e production manual
- Promotion via branches
- Promotion via diretórios

### Motivo da escolha

Staging automático acelera feedback e validação. Production manual reduz risco e permite revisão/aprovação antes de aplicar mudanças.

A promoção para production é feita via Pull Request alterando a tag da imagem no overlay de production. Isso garante rastreabilidade e controle.

---

## 14. GitHub Actions com OIDC

### Decisão

Usei GitHub Actions com OIDC para autenticação na AWS.

### Alternativas possíveis

- Access key salva como secret no GitHub
- OIDC com role assumida
- Runner self-hosted com credenciais locais

### Motivo da escolha

OIDC evita armazenar access keys long-lived no GitHub. A pipeline assume uma IAM Role temporária com permissões específicas.

Essa abordagem é mais segura e alinhada a boas práticas modernas de CI/CD.

---

## 15. Mesma imagem promovida entre ambientes

### Decisão

A estratégia recomendada é buildar a imagem uma vez e promover a mesma tag entre staging e production.

### Alternativas possíveis

- Rebuild da imagem em cada ambiente
- Uma imagem por ambiente
- Mesma imagem promovida por tag

### Motivo da escolha

Promover a mesma imagem reduz risco de diferença entre ambientes. O que foi validado em staging é exatamente o que será promovido para production.

A mudança entre ambientes acontece no overlay do Kustomize, alterando a tag da imagem.

---

## 16. Service interno com ClusterIP

### Decisão

Usei Service do tipo ClusterIP.

### Alternativas possíveis

- ClusterIP
- NodePort
- LoadBalancer
- Ingress

### Motivo da escolha

O enunciado pede acesso interno para consumo por outros serviços. Por isso, ClusterIP atende ao requisito sem expor a aplicação para internet.

Se houvesse necessidade de exposição externa, eu adicionaria Ingress Controller, AWS Load Balancer Controller, TLS e WAF.

---

# Fluxo completo da solução

```text
Developer Commit/PR
        ↓
GitHub Actions
        ↓
Build Docker
        ↓
Push para ECR
        ↓
Atualiza tag no Kustomize
        ↓
Commit automático
        ↓
ArgoCD detecta alteração
        ↓
Deploy no EKS
```

---

# O que eu faria diferente ou adicionaria com mais tempo

- HPA para autoscaling de Pods
- Karpenter ou Cluster Autoscaler para autoscaling de nodes
- Prometheus, Grafana e Alertmanager
- Loki ou CloudWatch Container Insights para logs
- Trivy no pipeline para scan de imagem
- Checkov ou tfsec para scan de Terraform
- Kyverno ou OPA Gatekeeper para políticas Kubernetes
- Cosign para assinatura de imagens
- Argo Rollouts para canary ou blue/green
- RDS Proxy para melhor gerenciamento de conexões
- Rotação automática de secrets
- Separação de staging e production em contas AWS diferentes
- AWS WAF se houvesse exposição externa

---

# Riscos e limitações da solução entregue

- A infraestrutura não foi aplicada em uma conta AWS real
- Alguns valores são placeholders, como Account ID, ARNs e nomes de bucket
- A senha do banco aparece como exemplo em `terraform.tfvars`; em produção deveria vir de um secret seguro do CI/CD ou ferramenta como SOPS
- O serviço está exposto apenas internamente via ClusterIP
- Não há observabilidade completa implementada
- Não há autoscaling de Pods ou nodes implementado
- Não há assinatura de imagens com Cosign
- Não há policy enforcement com Kyverno/OPA
- O RDS foi modelado de forma simplificada para o desafio

---

# Tecnologias utilizadas

- AWS
- Amazon EKS
- Terraform
- Docker
- Amazon ECR
- ArgoCD
- External Secrets Operator
- AWS Secrets Manager
- GitHub Actions
- Kubernetes
- Kustomize
