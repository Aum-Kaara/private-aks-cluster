
---

# **Azure Private AKS Cluster Deployment (Bicep)**

## **📘 Overview**

This repository contains **Bicep templates** to deploy a fully private, secure, enterprise-grade **AKS (Azure Kubernetes Service) cluster**.
The deployment ensures:

* Private API server (no public access)
* Secured networking with private endpoints
* Managed identities
* Azure CNI networking
* Best practices for security, availability, and governance

---

## **🛠️ Prerequisites**

Before deploying the Bicep templates, ensure the following:

### **🔹 Azure Requirements**

* Azure Subscription with permission:

  * **Owner** or
  * **Contributor + User Access Administrator**
* Registered providers:

  ```
  Microsoft.ContainerService
  Microsoft.Network
  Microsoft.Compute
  Microsoft.ManagedIdentity
  Microsoft.Storage
  ```

### **🔹 Tools Required**

| Tool          | Version  | Purpose                      |
| ------------- | -------- | ---------------------------- |
| **Azure CLI** | ≥ 2.58   | Deployment & authentication  |
| **Bicep CLI** | ≥ v0.27  | Build & validate Bicep files |
| **Kubectl**   | ≥ 1.29   | Post-deployment validation   |
| **Helm**      | Optional | App deployments              |

Install/update Bicep:

```sh
az bicep upgrade
```

### **🔹 Network Prerequisites**

Ensure space for the following VNets/subnets:

| Component               | Example CIDR |
| ----------------------- | ------------ |
| AKS VNet                | 10.0.0.0/16  |
| Node Subnet             | 10.0.1.0/24  |
| Private Endpoint Subnet | 10.0.2.0/24  |

### **🔹 (Optional) Jumpbox VM**

Since the AKS API server is private, access may require:

* Azure Bastion
* ExpressRoute / VPN
* Jumpbox VM within the same VNet

---

## **📁 Repository Structure**

```
/iac
  ├── main.bicep
  └── parameters.json

```

---

## **🚀 Deployment Guide**

### **1️⃣ Login to Azure**

```sh
az login
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"
```

---

### **2️⃣ Validate the Bicep Template**

```sh
az deployment group what-if \
  --resource-group <rg-name> \
  --template-file main.bicep \
  --parameters @parameters.json
```

---

### **3️⃣ Deploy**

```sh
az deployment group create \
  --resource-group <rg-name> \
  --template-file main.bicep \
  --parameters @parameters.json
```

---

## **🔎 Post-Deployment: Connect to AKS**

### **Fetch AKS Credentials**

Because the API server is private, ensure you are inside the VNet.

```sh
az aks get-credentials \
  --resource-group <rg-name> \
  --name <aks-name>
```

### **Validate Nodes**

```sh
kubectl get nodes
```

---

## **🏗️ Architecture Summary**

The solution provisions:

### **🔹 Networking**

* Spoke VNet for AKS
* Subnets:

  * Node subnet
  * Private endpoint subnet
* Private DNS zones for:

  * AKS API
  * ACR
  * Key Vault

---

### **🔹 AKS Cluster**

* Azure CNI networking
* Managed Identity
* Private API Server enabled
* RBAC enabled
* Autoscaling optional

---

### **🔹 ACR Integration**

* Dedicated Azure Container Registry
* Private endpoint for ACR
* Pull permissions granted to AKS Managed Identity

---

### **🔹 Security**

* No public IPs
* All traffic restricted to private endpoints
* NSG rules minimized
* Managed identity authorization
* Network isolation using spoke-hub model (optional)

---

## **📦 Cleanup**

```sh
az group delete --name <rg-name> --yes --no-wait
```

---

## **📄 License**

MIT License — free to use and modify.

---
