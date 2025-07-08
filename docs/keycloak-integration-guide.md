# MISP Keycloak 26.1.x Basic Integration Guide

This guide provides detailed instructions for integrating MISP with Keycloak using OpenID Connect (OIDC). It assumes that Keycloak is already installed and configured with a realm. Default settings are used unless otherwise specified.

On unauthenticated access to the MISP console, users will be redirected by nginx to KeyCloak for authentication. If the user does not already exist in the MISP console, it will be created automatically under the organisation defined in the environment variables.

## Client

### Create Client

This section outlines how to create and configure a Keycloak client for MISP. The client represents MISP in the Keycloak realm and facilitates authentication and authorization.

**Steps**
> Navigate to: `Manage -> Clients -> Create client`
     
1. **General Settings**
   - **Client Type**: OpenID Connect
   - **Client ID**: `misp`

2. **Capability Config**
   - **Client authentication**: `On`
   - **Authorization**: `On`
   - **Authentication Flow**: Enable `Standard flow`, `Direct access grants`, and `Service accounts roles`

3. **Login Settings**
   - **Root URL**: `<full URL of your MISP instance>` (e.g., `https://misp.domain.tld/`)
   - **Home URL**: Same as Root URL
   - **Valid Redirect URL**: `<Root URL appended with *>` (e.g., `https://misp.domain.tld/*`)
   - **Web Origins**: `<MISP hostname>` (e.g., `misp.domain.tld`)

### Define Roles

Define roles in Keycloak that correspond to MISP roles. These roles will be used to control access levels within MISP.

**Steps**

> Navigate to: `Manage -> Clients -> misp -> Roles -> Create Role`
1. **Role name**: e.g., `admin`

> Repeat this for every MISP role you want to assign through Keycloak (e.g., `admin`, `OrgAdmin`, `User`, `Read Only`, etc.)

### Assign Roles to Users

Assign the defined roles to specific users to control their access in MISP.

**Steps**

> Navigate to: `Manage -> Users -> <your user> -> Role mapping -> Assign Role`
  
1. Ensure “Filter by clients” is visible in the top left corner
2. Select the appropriate MISP role (e.g., `misp admin`)
3. Click `Assign`

> Alternatively, access can be assigned to groups using the same process.

## Client Scope

Client scopes define what information is included in the tokens issued to the client. This section sets up a custom client scope for MISP.

**Steps**

1. **Create Client Scope**
> Navigate to: `Manage -> Realm roles -> Create Client Scope`
  - **Name**: `misp-oidc`
  - **Type**: Optional
  - **Protocol**: OpenID Connect
  - **Include in token scope**: Off

2. **Configure Predefined Client Scope Mappers**
> Navigate to: `Manage -> Client Scopes -> misp-oidc -> Mappers -> Add Mapper -> From Predefined Mapper`
  - Select: `email`, `username`

3. **Configure Roles Client Mapper**
> Navigate to: `Manage -> Client Scopes -> misp-oidc -> Mappers -> Add Mapper -> By Configuration`
  - **Name**: `roles`
  - **Mapper Type**: `User Client Role`
  - **Client ID**: Select `misp` from dropdown
  - **Client Role Prefix**: Leave blank
  - **Multivalued**: On
  - **Token Claim Name**: `roles`
  - **Claim JSON Type**: String
  - **Add to ID token**: On
  - **Add to access token**: On
  - **Add to lightweight access token**: Off
  - **Add to userinfo**: On
  - **Add to token introspection**: On

4. **Add Scope to Client**
> Navigate to: `Manage -> Clients -> misp -> Client Scopes -> Add Client Scope`
  - Select `misp-oidc` -> Click `Add` -> Set as `Default`

---

## MISP Environment Variable Configuration

Configure MISP to use Keycloak as an OIDC provider by setting the appropriate environment variables. These variables must all be set to trigger configure_misp.sh to enable OIDC during setup.

### Required Variables

- `OIDC_ENABLE`: `"true"` — Enables OIDC authentication in MISP.
- `OIDC_CLIENT_ID`: `"misp"` — The client ID configured in Keycloak.
- `OIDC_DEFAULT_ORG`: `"[Org Name for default assignment]"` — The default organization name in MISP to associate with authenticated users.
- `OIDC_PROVIDER_URL`: `"https://[key.cloak.host]/realms/[realm-name]/.well-known/openid-configuration"` — The discovery URL for the Keycloak realm.
- `OIDC_ROLES_MAPPING`: `'{"admin":"1","user":"3"}'` — JSON mapping from Keycloak roles to MISP role IDs.
- `OIDC_ROLES_PROPERTY`: `"realm_access.roles"` — The claim path in the token where roles are listed.
- `OIDC_CLIENT_SECRET`: `<secret>` — The client secret from Keycloak (`Manage -> Clients -> misp -> Credentials -> Client Secret`)
Example:
```
  OIDC_ENABLE: "true"
  OIDC_CLIENT_ID: "misp"
  OIDC_DEFAULT_ORG: "ADMIN"
  OIDC_PROVIDER_URL: "https://auth.domain.com/realms/REALMNAME/.well-known/openid-configuration"
  OIDC_ROLES_MAPPING: '{"admin":"1","user":"3"}'
  OIDC_ROLES_PROPERTY: "roles"
```

---

## Troubleshooting

>Authentication errors are logged to the MISP error log `app/tmp/logs/error.log`

**Warning: OIDC user 'user@example.com' - Role Property 'roles' is missing in claims, access prohibitied**

This warning indicates an issue with the Client Scope Roles Mapper not correctly including the role in the token. Review the Client Scope configurations at `Manage -> Client Scopes -> misp-oidc -> Mappers` and `Manage -> Clients -> misp -> Client Scopes`

**Warning: OIDC user 'user@example.com' - No role was assigned, access prohibited**

The user authenticated in keycloak successfully, but they were not a member of any roles mapped to MISP. Ensure the user is a member of one of the client roles `Manage -> Clients -> misp -> Roles` and that the `OIDC_ROLES_MAPPING` variable correctly matches that role name (case sensitive) to a MISP role

**Error: OIDC user 'user@example.com" - User sub doesn't match, could not login**

The sub is a property mapping the username to the user's keycloak ID. This ID gets saved to the user in MISP. This most common causes of this error are the user was deleted and recreated in keycloak or if settings in keycloak were manually recreated. To resolve, delete the user from MISP and allow it to be recreated on next successful login.