# Transfer Family Web App Architecture

## Overview
The webapp module deploys a Transfer Family Web App with fine-grained S3 permissions using **S3 Access Grants** and **IAM Identity Center** for user authentication.

## Architecture Components

### 1. **S3 Buckets**

Two buckets are created:

#### **Uploads Bucket** (created by `webapp-location` module)
- **Purpose**: User-specific uploads
- **Naming**: `transfer-uploads-<random>`
- **Features**:
  - Versioning enabled
  - AES256 encryption
  - CORS configured for web app access
  - Public access blocked

#### **Shared Documents Bucket** (created in `stage4-webapp.tf`)
- **Purpose**: Shared team documents
- **Naming**: `transfer-shared-docs-<random>`
- **Features**:
  - Versioning enabled
  - AES256 encryption
  - Public access blocked

---

### 2. **S3 Access Grants Architecture**

S3 Access Grants provides **fine-grained, path-based permissions** without complex IAM policies.

#### **Access Grants Instance**
- One per AWS account (created in `stage0-foundation.tf`)
- Connected to IAM Identity Center
- Central authorization point

#### **Access Grants Locations**
Each S3 bucket/prefix becomes a "location":

```
Location 1: s3://transfer-uploads-xxx/
  └─ IAM Role: uploads-access-grants-role
     └─ Permissions: Read/Write to bucket

Location 2: s3://transfer-shared-docs-xxx/documents/
  └─ IAM Role: shared-docs-access-grants-role
     └─ Permissions: Read/Write to documents/ prefix
```

#### **Access Grants (Permissions)**
Individual grants map **Identity Center users/groups** to **S3 paths**:

```
Grant 1: claims.reviewer → s3://uploads/user/claims.reviewer/* (READWRITE)
Grant 2: claims.reviewer → s3://shared-docs/* (READ)
Grant 3: claims.administrator → s3://uploads/user/claims.administrator/* (READWRITE)
Grant 4: claims.administrator → s3://shared-docs/* (READWRITE)
Grant 5: Claims Team (group) → s3://shared-docs/* (READ)
```

---

### 3. **Identity Mapping Flow**

#### **Step 1: User Authentication**
```
User → IAM Identity Center → SAML Assertion → Transfer Family Web App
```

#### **Step 2: Application Assignment**
```terraform
resource "aws_ssoadmin_application_assignment" "users" {
  application_arn = transfer_web_app.application_arn
  principal_id    = identity_center_user.user_id
  principal_type  = "USER"
}
```
- Users/groups are assigned to the Transfer Web App via Identity Center
- This allows them to authenticate and access the web interface

#### **Step 3: S3 Access Resolution**
When a user tries to access S3:

```
1. User authenticates → Identity Center provides user_id
2. Transfer Web App assumes Bearer Role
3. Bearer Role calls s3:GetDataAccess with user_id
4. S3 Access Grants evaluates:
   - Which locations does this user have grants for?
   - What paths are they allowed to access?
   - What permissions (READ/READWRITE)?
5. Returns temporary credentials scoped to allowed paths
6. User accesses S3 with scoped credentials
```

---

### 4. **IAM Roles**

#### **Bearer Role** (Transfer Web App)
```json
{
  "Principal": {"Service": "transfer.amazonaws.com"},
  "Action": ["sts:SetContext", "sts:AssumeRole"],
  "Permissions": [
    "s3:GetDataAccess",
    "s3:ListCallerAccessGrants",
    "s3:ListAccessGrantsInstances"
  ]
}
```
- Assumed by Transfer Family service
- Calls S3 Access Grants to get user permissions

#### **Location Roles** (per S3 bucket/prefix)
```json
{
  "Principal": {"Service": "access-grants.s3.amazonaws.com"},
  "Action": ["sts:AssumeRole", "sts:SetContext"],
  "Permissions": [
    "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
    "s3:ListBucket"
  ],
  "Resource": "s3://bucket/prefix/*"
}
```
- Assumed by S3 Access Grants service
- Provides actual S3 permissions for the location

---

### 5. **Permission Examples**

#### **claims.reviewer User**
```
✅ Can read/write: s3://uploads/user/claims.reviewer/my-file.pdf
❌ Cannot access: s3://uploads/user/claims.administrator/file.pdf
✅ Can read: s3://shared-docs/documents/policy.pdf
❌ Cannot write: s3://shared-docs/documents/policy.pdf
```

#### **claims.administrator User**
```
✅ Can read/write: s3://uploads/user/claims.administrator/report.pdf
✅ Can read/write: s3://shared-docs/documents/policy.pdf
✅ Can delete: s3://shared-docs/documents/old-file.pdf
```

#### **Claims Team Group**
```
✅ Can read: s3://shared-docs/documents/team-policy.pdf
❌ Cannot write: s3://shared-docs/documents/team-policy.pdf
❌ Cannot access: s3://uploads/user/*/
```

---

### 6. **Configuration in stage4-webapp.tf**

```terraform
users = [
  {
    username = "claims.reviewer"
    access_grants = [
      {
        location_id = uploads_location.id
        path        = "user/claims.reviewer/*"  # User-specific folder
        permission  = "READWRITE"
      },
      {
        location_id = shared_location.id
        path        = "*"                        # All shared docs
        permission  = "READ"                     # Read-only
      }
    ]
  }
]

groups = [
  {
    group_name = "Claims Team"
    access_grants = [
      {
        location_id = shared_location.id
        path        = "*"
        permission  = "READ"
      }
    ]
  }
]
```

---

## Key Benefits

1. **Fine-Grained Permissions**: Path-level access control without complex IAM policies
2. **Identity Integration**: Direct mapping from Identity Center users to S3 paths
3. **Scalable**: Add users/groups without modifying IAM policies
4. **Auditable**: All access logged via CloudTrail with user identity
5. **Secure**: Temporary credentials scoped to exact paths needed

---

## Data Flow

```
┌─────────────────┐
│  User Browser   │
└────────┬────────┘
         │ 1. Authenticate
         ▼
┌─────────────────────────┐
│  IAM Identity Center    │
└────────┬────────────────┘
         │ 2. SAML Assertion
         ▼
┌─────────────────────────┐
│ Transfer Family Web App │
└────────┬────────────────┘
         │ 3. Assume Bearer Role
         ▼
┌─────────────────────────┐
│   S3 Access Grants      │ ◄─── Evaluates grants for user_id
└────────┬────────────────┘
         │ 4. Return scoped credentials
         ▼
┌─────────────────────────┐
│   S3 Bucket (uploads)   │
│   S3 Bucket (shared)    │
└─────────────────────────┘
```

---

## Terraform Module Structure

```
stage4-webapp.tf
├── aws_s3_bucket.shared_docs
├── module.transfer_webapp
│   ├── awscc_transfer_web_app.main
│   └── aws_iam_role.transfer_web_app (Bearer Role)
├── module.uploads_location
│   ├── aws_s3_bucket.location (uploads bucket)
│   ├── aws_iam_role.location (Location Role)
│   └── aws_s3control_access_grants_location.location
├── module.shared_location
│   ├── aws_iam_role.location (Location Role)
│   └── aws_s3control_access_grants_location.location
└── module.webapp_users_and_groups
    ├── aws_ssoadmin_application_assignment.users
    ├── aws_ssoadmin_application_assignment.groups
    ├── aws_s3control_access_grant.user_grants
    └── aws_s3control_access_grant.group_grants
```

---

## Summary

The webapp module creates a **zero-trust, fine-grained access control system** where:
- Users authenticate via Identity Center
- S3 Access Grants maps user identities to specific S3 paths
- No broad IAM policies needed
- Each user gets exactly the permissions they need, nothing more
