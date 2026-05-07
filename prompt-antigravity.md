# 🚀 PROMPT ANTIGRAVITY — Adaptation Infrastructure Cloud AWS pour ShopVault

---

## 🎯 OBJECTIF GLOBAL

Tu es un expert AWS Cloud Architect, Terraform Engineer, DevOps Engineer et CI/CD Specialist.

Tu dois **adapter UNIQUEMENT l'infrastructure cloud, l'architecture Terraform, la logique de déploiement et le pipeline CI/CD** d'un projet e-commerce existant appelé **ShopVault**, afin qu'il respecte **strictement** les exigences d'un projet académique décrites ci-dessous.

### ⚠️ CONTRAINTES ABSOLUES — À LIRE EN PREMIER

- ✅ CONSERVER le frontend Next.js existant
- ✅ CONSERVER le backend Node.js/Express existant
- ✅ CONSERVER les technologies existantes
- ✅ CONSERVER les Dockerfiles existants si possible
- ✅ CONSERVER la logique métier frontend/backend
- ❌ NE PAS recréer l'application depuis zéro
- ❌ NE PAS réécrire les fonctionnalités applicatives existantes
- ❌ NE PAS utiliser Elastic Beanstalk (explicitement interdit par le professeur)

**Modifier UNIQUEMENT :**
- L'infrastructure Terraform
- L'architecture AWS
- Le réseau (VPC, subnets, routage)
- La stratégie de déploiement EC2
- L'Auto Scaling Group
- L'ALB (Application Load Balancer)
- L'architecture RDS
- Les Security Groups
- Les scripts User Data
- Les workflows CI/CD GitHub Actions
- La stratégie de déploiement Docker

---

## 📋 CONTEXTE DU PROJET EXISTANT

### Description de l'application ShopVault

ShopVault est une plateforme e-commerce full-stack avec :
- **Frontend** : Next.js 14, Tailwind CSS, Zustand
- **Backend** : Node.js 20, Express, Prisma ORM
- **Base de données** : PostgreSQL 14 (AWS RDS)
- **Auth** : JWT (access token 15min + refresh token 7j, cookie httpOnly)
- **Paiements** : Stripe (mode test)
- **IaC** : Terraform ~> 4.67 (compatible AWS Academy)
- **CI/CD** : GitHub Actions + Docker Hub

### Architecture actuelle (NON CONFORME)

```
Internet
    │
    ▼
CloudFront (CDN — HTTPS)
    │
    ▼
ALB (Application Load Balancer — HTTP)
    │
    ├── /        → Frontend (Next.js)  → port 3000
    └── /api/*   → Backend (Node.js)   → port 4000
                         │
                         ▼
                   RDS PostgreSQL 14
```

**Infrastructure actuelle :**

```
VPC (10.0.0.0/16)
├── Public Subnets  (AZ-a + AZ-b)  → ALB + EC2 (frontend + backend ensemble)
└── Private Subnets (AZ-a + AZ-b)  → RDS uniquement
```

### Modules Terraform existants

```
infrastructure/
├── main.tf
├── variables.tf
├── outputs.tf
├── environments/
│   └── dev.tfvars
└── modules/
    ├── vpc/            ← À refactorer
    ├── ecs/            ← À remplacer/refactorer (pas d'ECS/Fargate)
    ├── rds/            ← À adapter
    ├── s3/             ← À conserver
    └── cloudfront/     ← À adapter ou supprimer selon conformité
```

### Workflows CI/CD existants

```
.github/workflows/
├── ci.yml          ← À adapter
├── deploy.yml      ← À refactorer complètement
└── redeploy.yml    ← À adapter
```

---

## 🔍 ANALYSE REQUISE — CE QUE TU DOIS FAIRE EN PREMIER

Avant de générer quoi que ce soit, tu dois :

1. **Analyser l'architecture existante** décrite dans ce prompt (README)
2. **Analyser les exigences du professeur** décrites dans la section "Exigences requises" ci-dessous
3. **Comparer** l'architecture existante vs l'architecture requise
4. **Identifier les composants non conformes** et lister les écarts
5. **Proposer un plan de migration** clair et structuré
6. **Générer uniquement les fichiers nécessaires** à l'adaptation

---

## 📐 EXIGENCES REQUISES PAR LE PROFESSEUR — ARCHITECTURE CIBLE

### ① Réseau — VPC

Terraform DOIT provisionner :

- **1 VPC** avec le bloc CIDR `10.0.0.0/16`
- **2 Zones de Disponibilité** (AZ-A et AZ-B) pour la résilience
- Dans chaque AZ : **1 sous-réseau public + 1 sous-réseau privé** → 4 sous-réseaux au total
- **1 Internet Gateway** — pour le trafic internet entrant
- **1 NAT Gateway** (dans un sous-réseau public) — pour que les instances privées accèdent à internet
- **Tables de routage** correctement configurées pour sous-réseaux publics et privés
- **Associations** de tables de routage

**Sous-réseaux publics accueillent :**
- ALB (Application Load Balancer)
- NAT Gateway
- Instance EC2 Frontend

**Sous-réseaux privés accueillent :**
- Instances EC2 Backend (via Auto Scaling Group)
- Instance RDS PostgreSQL

### ② Backend — EC2 + ALB + Auto Scaling Group

**Application Load Balancer :**
- Placé dans les **deux sous-réseaux publics**
- Redirige le trafic vers les instances backend
- Utilise un **Target Group** avec health check
- Health check : `GET /health` → HTTP 200

**Launch Template :**
- Inclut un script **User Data** de déploiement automatique
- Démarre l'application automatiquement au boot
- Injecte les variables d'environnement (DB_HOST, DB_PASS, etc.)
- Effectue un `git clone` ou un `docker pull` automatique

Exemple de script User Data attendu :

```bash
#!/bin/bash
sudo apt update -y && sudo apt install -y git nodejs npm
cd /home/ubuntu
git clone https://github.com/<org>/<repo>.git app
cd app/backend
npm install
export DB_HOST=<endpoint-rds>
export DB_PASS=<mot-de-passe>
export DATABASE_URL=postgresql://<user>:${DB_PASS}@${DB_HOST}:5432/<dbname>
export JWT_SECRET=<jwt-secret>
export JWT_REFRESH_SECRET=<jwt-refresh-secret>
npm run start &
```

**Auto Scaling Group :**
- `min = 2`, `desired = 2`, `max = 4`
- Réparti sur les **deux sous-réseaux privés**
- Lié au Launch Template

**Scaling Policy CPU :**
- Scale out si **CPU > 70%**

### ③ Frontend

- **1 instance EC2 dédiée** dans un **sous-réseau public**
- Accessible en HTTP depuis internet (port 80)
- Le frontend communique **UNIQUEMENT avec le DNS de l'ALB backend**
- **JAMAIS** via l'IP directe d'une instance EC2 backend
- Terraform DOIT automatiser le déploiement frontend

**Stratégie de déploiement frontend :**
- Option A (recommandée) : User Data avec nginx + `docker pull` image frontend Docker Hub
- Option B : User Data avec nginx + `git clone` + `npm run build` + `npm start`
- Le frontend Next.js tourne sur le port 3000, nginx reverse-proxie le port 80

### ④ Base de Données — Amazon RDS PostgreSQL

- **PostgreSQL** (moteur)
- **db.t3.micro** (instance type)
- Déployée dans un **DB Subnet Group** utilisant les **deux sous-réseaux privés**
- **Pas accessible publiquement** (`publicly_accessible = false`)
- Le mot de passe DOIT être injecté via **variable d'environnement** ou **secret GitHub**
- **JAMAIS** en dur dans le code Terraform

---

## 🔒 EXIGENCES SECURITY GROUPS — CRITIQUES POUR L'ÉVALUATION

Le correcteur vérifiera **chaque règle de chaque Security Group** pendant la démonstration.

### Security Group ALB

| Direction | Port | Source | Action |
|-----------|------|--------|--------|
| Inbound   | 80   | 0.0.0.0/0 | ALLOW |
| Outbound  | All  | 0.0.0.0/0 | ALLOW |

### Security Group EC2 Backend

| Direction | Port            | Source                  | Action |
|-----------|-----------------|-------------------------|--------|
| Inbound   | 4000 (ou port app) | SG ALB uniquement    | ALLOW  |
| Outbound  | All             | 0.0.0.0/0               | ALLOW  |

> ⚠️ **PAS d'accès depuis internet directement. PAS de règle 0.0.0.0/0 en inbound.**

### Security Group RDS

| Direction | Port | Source                      | Action |
|-----------|------|-----------------------------|--------|
| Inbound   | 5432 | SG EC2 Backend uniquement   | ALLOW  |
| Outbound  | All  | 0.0.0.0/0                   | ALLOW  |

> ⚠️ **Aucune règle depuis internet. Aucune règle depuis 0.0.0.0/0 sur le port 5432. Jamais depuis votre ordinateur.**

### Security Group EC2 Frontend

| Direction | Port | Source      | Action |
|-----------|------|-------------|--------|
| Inbound   | 80   | 0.0.0.0/0   | ALLOW  |
| Inbound   | 22   | Votre IP uniquement (ou 0.0.0.0/0 si debug nécessaire) | ALLOW |
| Outbound  | All  | 0.0.0.0/0   | ALLOW  |

---

## 🧱 EXIGENCES TERRAFORM

### Structure cible obligatoire

```
infrastructure/
├── main.tf                   ← Module racine
├── variables.tf              ← Variables globales
├── outputs.tf                ← Outputs globaux
├── environments/
│   └── dev.tfvars            ← Variables d'environnement dev
└── modules/
    ├── vpc/                  ← À refactorer
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── alb/                  ← À créer (nouveau module)
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── backend_asg/          ← À créer (remplace module ecs/)
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── frontend_ec2/         ← À créer
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── rds/                  ← À adapter
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── s3/                   ← À conserver (state bucket)
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

### Fichiers à supprimer

- `modules/ecs/` → Remplacé par `modules/backend_asg/` et `modules/alb/`
- `modules/cloudfront/` → CloudFront n'est PAS requis par le professeur (optionnel)

### Fichiers à modifier

- `modules/vpc/` → Ajouter NAT Gateway, adapter le routage
- `modules/rds/` → Adapter DB Subnet Group, enlever accès public
- `main.tf` racine → Câbler les nouveaux modules
- `variables.tf` → Ajouter les nouvelles variables
- `outputs.tf` → Ajouter ALB DNS, frontend IP, etc.
- `environments/dev.tfvars` → Mettre à jour les valeurs

### Fichiers à conserver

- `modules/s3/` → Conservé tel quel pour le state bucket Terraform

### Contraintes AWS Academy Sandbox

```hcl
# Provider compatible avec AWS Academy
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.67"
    }
  }
  required_version = ">= 1.6.0"
}
```

- Utiliser le **LabRole existant** (pas de `aws_iam_role` custom)
- Utiliser le **LabInstanceProfile existant** (pas de `aws_iam_instance_profile` custom)
- **NE PAS utiliser** : Elastic Beanstalk, Fargate, Secrets Manager, ACM sur ALB, Object Lock S3
- Les credentials AWS expirent toutes les 4h → workflow `redeploy.yml` obligatoire

---

## 🐳 EXIGENCES DOCKER

- **Réutiliser** les Dockerfiles existants (`backend/Dockerfile` et `frontend/Dockerfile`)
- **Conserver** le support Docker
- Utiliser **Docker Hub** comme registry de conteneurs
- Images à construire et pousser :
  - `<dockerhub-username>/shopvault-backend:latest`
  - `<dockerhub-username>/shopvault-frontend:latest`

**Dans le script User Data :**
- Les instances EC2 font un `docker pull` depuis Docker Hub
- Les images sont démarrées via `docker run`

---

## 🔄 EXIGENCES CI/CD — GITHUB ACTIONS

### Workflow `ci.yml` — Intégration Continue

Déclenché sur : `pull_request` vers `main`

Étapes obligatoires :
1. Checkout du code
2. Installation des dépendances backend (`npm install`)
3. Installation des dépendances frontend (`npm install`)
4. Lint backend
5. Tests backend
6. Build frontend (`npm run build`)
7. Validation Terraform (`terraform validate`)

### Workflow `deploy.yml` — Déploiement Complet

Déclenché sur : `push` vers `main`

Étapes obligatoires dans l'ordre :
1. Checkout du code
2. Login Docker Hub (via secrets GitHub)
3. Build image Docker backend
4. Push image backend vers Docker Hub
5. Build image Docker frontend
6. Push image frontend vers Docker Hub
7. Configuration AWS credentials (via secrets GitHub)
8. `terraform init` (avec backend S3)
9. `terraform validate`
10. `terraform plan -var-file=environments/dev.tfvars`
11. `terraform apply -auto-approve -var-file=environments/dev.tfvars`
12. Affichage du DNS ALB et IP frontend dans les logs

### Workflow `redeploy.yml` — Récupération Rapide

Déclenché sur : `workflow_dispatch` (manuel)

Input : `skip_build` (boolean) — réutilise les images Docker existantes si `true`

Étapes :
1. (Conditionnel) Build + Push images Docker si `skip_build = false`
2. Mise à jour des credentials AWS
3. `terraform init`
4. `terraform apply -auto-approve` (réutilise le state existant)

### GitHub Secrets requis

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | Depuis AWS Academy Learner Lab |
| `AWS_SECRET_ACCESS_KEY` | Depuis AWS Academy Learner Lab |
| `AWS_SESSION_TOKEN` | Depuis AWS Academy Learner Lab |
| `AWS_REGION` | `us-east-1` |
| `DOCKERHUB_USERNAME` | Nom d'utilisateur Docker Hub |
| `DOCKERHUB_TOKEN` | Personal Access Token Docker Hub |
| `DB_PASSWORD` | Mot de passe RDS |
| `JWT_SECRET` | Chaîne hexadécimale aléatoire 128 chars |
| `JWT_REFRESH_SECRET` | Chaîne hexadécimale aléatoire 128 chars |
| `STRIPE_SECRET_KEY` | Clé secrète Stripe (test) |
| `STRIPE_WEBHOOK_SECRET` | Secret webhook Stripe |
| `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` | Clé publique Stripe |

---

## 🗺️ STRATÉGIE DE MIGRATION

### Analyse des écarts (Existant vs Requis)

| Composant | Situation Actuelle | Situation Requise | Action |
|-----------|-------------------|-------------------|--------|
| Frontend | EC2 dans ALB path `/` | EC2 dédié dans subnet public | Créer module `frontend_ec2` |
| Backend | EC2 dans subnet public via ALB | EC2 dans subnet PRIVÉ via ASG | Refactorer module `ecs` → `backend_asg` |
| ALB | ALB gérant frontend + backend | ALB uniquement pour backend | Modifier module `alb` |
| CloudFront | Présent | Non requis (optionnel) | Supprimer ou désactiver |
| NAT Gateway | Absent ou non configuré | Requis pour subnets privés | Ajouter dans module `vpc` |
| ASG | Absent | Requis (min=2, max=4) | Créer module `backend_asg` |
| Launch Template | Absent | Requis pour ASG | Créer dans module `backend_asg` |
| RDS Security Group | Probablement ouvert | Uniquement depuis SG backend | Corriger module `rds` |

### Commandes de migration

```bash
# 1. Détruire l'infrastructure existante non conforme
cd infrastructure
terraform destroy -var-file=environments/dev.tfvars -auto-approve

# 2. Valider le nouveau code Terraform
terraform init
terraform validate
terraform plan -var-file=environments/dev.tfvars

# 3. Appliquer la nouvelle infrastructure
terraform apply -var-file=environments/dev.tfvars -auto-approve

# 4. Vérifier les outputs
terraform output
```

> ⚠️ Effectuer la migration via le workflow GitHub Actions `deploy.yml` est préférable pour la traçabilité.

---

## 📦 LIVRABLES ATTENDUS EN SORTIE

Ta réponse DOIT inclure dans l'ordre :

### 1. Analyse et Plan de Migration
- Liste des composants non conformes détectés
- Tableau des écarts (existant vs requis)
- Plan de migration structuré

### 2. Fichiers Terraform Complets

Chaque fichier doit être présenté avec son chemin complet et son contenu intégral :

- `infrastructure/main.tf`
- `infrastructure/variables.tf`
- `infrastructure/outputs.tf`
- `infrastructure/environments/dev.tfvars`
- `infrastructure/modules/vpc/main.tf`
- `infrastructure/modules/vpc/variables.tf`
- `infrastructure/modules/vpc/outputs.tf`
- `infrastructure/modules/alb/main.tf`
- `infrastructure/modules/alb/variables.tf`
- `infrastructure/modules/alb/outputs.tf`
- `infrastructure/modules/backend_asg/main.tf` (Launch Template + ASG + Scaling Policy)
- `infrastructure/modules/backend_asg/variables.tf`
- `infrastructure/modules/backend_asg/outputs.tf`
- `infrastructure/modules/frontend_ec2/main.tf`
- `infrastructure/modules/frontend_ec2/variables.tf`
- `infrastructure/modules/frontend_ec2/outputs.tf`
- `infrastructure/modules/rds/main.tf`
- `infrastructure/modules/rds/variables.tf`
- `infrastructure/modules/rds/outputs.tf`

### 3. Scripts User Data

- Script User Data complet pour les instances **EC2 Backend** (ASG)
- Script User Data complet pour l'instance **EC2 Frontend**

### 4. Workflows GitHub Actions

- `.github/workflows/ci.yml` (complet)
- `.github/workflows/deploy.yml` (complet)
- `.github/workflows/redeploy.yml` (complet)

### 5. Documentation

- Explication de chaque modification effectuée
- Explication de la stratégie de déploiement
- Instructions de migration pas à pas
- Commandes de vérification post-déploiement

### 6. Diagramme d'Architecture Finale

Représentation ASCII de l'architecture cible :

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│                    VPC 10.0.0.0/16                      │
│                                                         │
│  ┌─────────────────────┐  ┌─────────────────────┐       │
│  │  Public Subnet AZ-A │  │  Public Subnet AZ-B │       │
│  │                     │  │                     │       │
│  │  [NAT GW]           │  │                     │       │
│  │  [Frontend EC2]     │  │                     │       │
│  │  [ALB Node]         │  │  [ALB Node]          │       │
│  └─────────────────────┘  └─────────────────────┘       │
│                                                         │
│  ┌─────────────────────┐  ┌─────────────────────┐       │
│  │  Private Subnet AZ-A│  │  Private Subnet AZ-B│       │
│  │                     │  │                     │       │
│  │  [Backend EC2 ASG]  │  │  [Backend EC2 ASG]  │       │
│  │  [RDS Primary]      │  │  [RDS Standby]      │       │
│  └─────────────────────┘  └─────────────────────┘       │
└─────────────────────────────────────────────────────────┘
```

---

## ⚠️ RÈGLES DE GÉNÉRATION STRICTES

Tu NE DOIS PAS :
- Réécrire la logique métier du frontend Next.js
- Réécrire les contrôleurs/routes/services du backend
- Recréer les migrations Prisma
- Modifier le schéma de base de données
- Changer les technologies utilisées

Tu DOIS :
- Générer des fichiers Terraform complets et fonctionnels
- Générer des scripts User Data complets et testables
- Générer des workflows GitHub Actions complets et fonctionnels
- Respecter les contraintes AWS Academy Sandbox
- Respecter exactement les règles de Security Groups du professeur
- Documenter chaque fichier généré

---

## 🏁 INSTRUCTION FINALE

Commence par afficher un résumé de ton analyse des écarts, puis génère **tous les fichiers listés dans la section "Livrables"** dans l'ordre, avec les chemins complets et les blocs de code complets. Ne résume pas les fichiers — génère leur contenu intégral.
