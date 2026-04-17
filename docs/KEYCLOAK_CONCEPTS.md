---
noteId: "4cdf17c03a5b11f193731ba5952ee8de"
tags: []

---

# Keycloak Concepts for First-Timers

This guide explains fundamental Keycloak concepts that you need to understand to work with AGM Keycloak.

## What is Keycloak?

Keycloak is an **open-source Identity and Access Management (IAM) server**. Think of it as a central hub that:

- 🔐 **Authenticates users** (verifies they are who they say they are)
- 🔑 **Manages user accounts** (passwords, profiles, security settings)
- 🛡️ **Authorizes applications** (controls what users can do)
- 🌐 **Federates identities** (connects to external systems like LDAP)
- 📱 **Provides SSO** (Single Sign-On - log in once, access multiple apps)

### Real-World Analogy

Think of Keycloak like a **hotel key card system**:

```
┌──────────────────────────────────────┐
│  KEYCLOAK (Like Hotel Front Desk)    │
│                                      │
│  - Checks your ID (Authentication)   │
│  - Issues a key card (Token)         │
│  - Tracks where you can go (Authz)   │
└──────────────────────────────────────┘
         │              │              │
         ▼              ▼              ▼
    ┌────────┐    ┌────────┐    ┌────────┐
    │ Gym    │    │ Pool   │    │ Restaurant
    │(App 1) │    │(App 2) │    │(App 3)
    └────────┘    └────────┘    └────────┘
```

---

## Key Concepts

### 1. **Realm** - Your Virtual Realm/Tenant
A **realm** is an isolated instance of Keycloak with its own users, clients, and settings.

**Think of it as:** A separate hotel with its own front desk, users, and rules.

```
Keycloak Server
├── Realm: "MyCompany"
│   ├── Users: (Alice, Bob, Charlie)
│   ├── Clients: (MyApp, MobileApp, WebApp)
│   └── Roles: (Admin, User, Viewer)
│
├── Realm: "Partner"
│   ├── Users: (David, Eve)
│   ├── Clients: (PartnerApp)
│   └── Roles: (Partner, Guest)
│
└── Realm: "agm"  ← This is what we're building!
    ├── Users: (user1, user2)
    ├── Clients: (Your Applications)
    └── Roles: (Various permissions)
```

**For AGM**, we'll create ONE realm called "agm" with 2 users.

---

### 2. **Users** - People Who Log In
Users are people who authenticate to your realm.

```
User: user1
├── Username: "user1"
├── Email: "user1@agm.com"
├── Password: "secure-password"
├── First Name: "John"
├── Last Name: "Doe"
├── Roles: ["admin", "developer"]
└── Attributes: [{"key": "department", "value": "engineering"}]
```

**For AGM MVP**, we'll create 2 users with basic credentials.

---

### 3. **Clients** - Applications That Need Auth
Clients are applications that want to authenticate users with Keycloak.

**Think of it as:** Companies that want to use the hotel's key card system.

```
Client: "agm-frontend"  (React web app)
├── Client Type: OIDC (OpenID Connect)
├── Access Type: public/confidential
├── Redirect URIs: ["http://localhost:3000/callback"]
└── Credentials: client_id, client_secret

Client: "agm-mobile"  (Mobile app)
├── Client Type: OIDC
├── Access Type: public
└── Redirect URIs: ["agm://callback"]
```

Your applications will:
1. Redirect users to Keycloak login
2. Keycloak authenticates the user
3. User gets redirected back to your app with a token
4. Your app uses the token to identify the user

---

### 4. **Roles** - Permissions & Groups
Roles define what users can do in your application.

```
Realm: "agm"
├── Roles:
│   ├── "admin" - Can do everything
│   ├── "user" - Can read/write limited data
│   ├── "viewer" - Can only view data
│   └── "developer" - Can access developer features
│
User: "user1"
├── Has roles: ["admin", "developer"]
```

Your application checks the user's roles:
```javascript
// In your app
if (user.roles.includes("admin")) {
  showAdminDashboard();
} else {
  showUserDashboard();
}
```

---

### 5. **Tokens** - Proof of Identity
When a user logs in, Keycloak gives them a **token** - proof that they've been authenticated.

**Types of tokens:**

#### Access Token
```
{
  "sub": "user1",
  "name": "John Doe",
  "email": "user1@agm.com",
  "realm_access": {
    "roles": ["admin", "developer"]
  },
  "exp": 1693478400  // Expires in 1 hour
}
```
- Short-lived (usually 1 hour)
- Used to access your application's API
- Contains user info and roles

#### Refresh Token
```
refresh_token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```
- Long-lived (usually days/weeks)
- Used to get a new access token when it expires
- Keeps users logged in without re-entering password

---

### 6. **Authentication Flows** - How Login Works

#### Standard Web App Flow (OIDC Authorization Code Flow)

```
1. User visits your web app
2. App redirects to Keycloak login:
   https://keycloak.example.com/realms/agm/protocol/openid-connect/auth?
     client_id=agm-frontend&
     redirect_uri=http://localhost:3000/callback&
     response_type=code

3. User sees Keycloak login page
   ↓
4. User enters username & password
   ↓
5. Keycloak verifies credentials and redirects back:
   http://localhost:3000/callback?code=ABC123

6. Your app exchanges code for tokens:
   POST /realms/agm/protocol/openid-connect/token
   Body: {code: "ABC123", client_id: "...", client_secret: "..."}
   Response: {access_token: "...", refresh_token: "..."}

7. Your app now has tokens! User is logged in! ✓
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────┐
│                 Your Application                │
│              (React, Node, Java, etc)           │
│  - Shows login button                           │
│  - Uses user info from token                    │
│  - Makes API calls with access token           │
└────────────────┬────────────────────────────────┘
                 │
        ┌────────┼────────┐
        │                 │
        ▼                 ▼
┌──────────────┐  ┌──────────────────┐
│ Browser/     │  │ Your Backend API │
│ Mobile Client│  │                  │
└──────────────┘  └──────────────────┘
        │                 │
        │ Redirect to     │ Validate
        │ login           │ token
        │                 │
        ▼─────────────────▼─────────────┐
        │                                │
        └──────────────────┬─────────────┘
                           │
                    ┌──────▼──────┐
                    │  KEYCLOAK   │
                    │             │
                    │  ┌────────┐ │
                    │  │  AGM   │ │  ← Our realm
                    │  │ Realm  │ │
                    │  │        │ │
                    │  │Users:  │ │
                    │  │-user1  │ │
                    │  │-user2  │ │
                    │  └────────┘ │
                    │             │
                    │ - Stores    │
                    │ - Verifies  │
                    │ - Issues    │
                    │   tokens    │
                    └─────────────┘
```

---

## Key Files in Keycloak Configuration

### realm-export.json
This is a **complete backup/definition of your realm**:

```json
{
  "id": "agm",
  "realm": "agm",
  "displayName": "AGM Realm",
  "enabled": true,
  
  "users": [
    {
      "id": "user1-id",
      "username": "user1",
      "email": "user1@agm.com",
      "firstName": "User",
      "lastName": "One",
      "emailVerified": true,
      "enabled": true
    },
    {
      "id": "user2-id",
      "username": "user2",
      "email": "user2@agm.com",
      ...
    }
  ],
  
  "clients": [
    {
      "clientId": "agm-frontend",
      "name": "AGM Frontend",
      "enabled": true,
      "redirectUris": ["http://localhost:3000/callback"],
      ...
    }
  ],
  
  "roles": {
    "realm": [
      {"name": "admin"},
      {"name": "user"},
      {"name": "viewer"}
    ]
  }
}
```

This file is:
- ✅ Version-controlled (in git)
- ✅ Reproducible (same settings everywhere)
- ✅ Used to auto-import realm on container startup

---

## Keycloak Admin Console

The admin console is where you configure everything visually:

```
https://keycloak.example.com/admin/

Login with:
- Username: keycloak (admin user)
- Password: password

Then navigate to:
- Realms → Select "agm"
  - Users → Manage users
  - Clients → Manage applications
  - Roles → Manage permissions
  - Authentication → Configure login flows
  - Email → Configure email sending
```

---

## Common Workflows

### Scenario 1: User Logs In
```
1. User visits your app
2. Clicks "Login"
3. Redirected to Keycloak
4. Enters username: "user1", password: "pwd123"
5. Keycloak validates against its database
6. ✓ Valid! Creates token
7. User redirected back to app
8. App stores token
9. User is now logged in!
```

### Scenario 2: User Accesses Protected Resource
```
1. User clicks "View Admin Dashboard"
2. App checks token for "admin" role
3. ✓ Has admin role!
4. Shows dashboard
```

If user doesn't have role:
```
1. User clicks "View Admin Dashboard"
2. App checks token for "admin" role
3. ✗ No admin role
4. Shows error: "Access Denied"
```

### Scenario 3: Token Expires
```
1. User has been logged in for 1 hour
2. Access token expires
3. App uses refresh token to get new access token
4. User continues using app without re-logging in
```

---

## What's Next?

Now that you understand the concepts:

1. **Build Keycloak** → Run Maven (currently in progress!)
2. **Start Keycloak** → Use Docker Compose
3. **Access Admin Console** → Create "agm" realm
4. **Create 2 Users** → user1, user2
5. **Export Realm** → Save realm-export.json
6. **Automate Import** → Docker will auto-import on startup

---

## Quick Reference

| Term | Meaning |
|------|---------|
| **Realm** | Isolated instance of Keycloak (like a tenant) |
| **User** | Person who logs in |
| **Client** | Application that needs authentication |
| **Role** | Permission level (admin, user, viewer) |
| **Token** | Proof of authentication (JWT) |
| **Access Token** | Short-lived token to use your app |
| **Refresh Token** | Long-lived token to get new access token |
| **OIDC** | OpenID Connect (authentication standard) |
| **SSO** | Single Sign-On (log in once, access multiple apps) |
| **LDAP** | Connect to corporate directory (future feature) |

---

## Learning Resources

- [Official Keycloak Getting Started](https://www.keycloak.org/getting-started)
- [Keycloak Server Administration](https://www.keycloak.org/docs/latest/server_admin/)
- [OpenID Connect Explained](https://openid.net/connect/)
- [JWT (JSON Web Tokens) Basics](https://jwt.io/introduction)

---

## Next Steps

Once the Maven build completes:
1. Start Keycloak with Docker Compose
2. Log into admin console
3. Create the "agm" realm
4. Add 2 test users
5. Export realm JSON
6. Version control it!
