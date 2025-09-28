# Environment Variable Management and Generation

This document explains the automated process for generating the runtime `.env` files required by the Docker Compose services. The system uses a two-phase approach to provide a flexible, transparent, and secure way to manage configuration.

## Overview

The process works as follows:

1.  **Phase 1: Schema Generation**: The build script reads `.env.*.tpl` template files from `src/env/` and generates a structured YAML schema (`vars.yaml`) that defines all possible environment variables, their properties (required, default value), and any secret generation rules.

2.  **Phase 2: Environment Rendering**: A rendering script processes the `vars.yaml` schema to produce the final `.env.*` files (e.g., `.env.n8n`, `.env.postgres`). It resolves the final value for each variable based on a strict precedence order: user overrides, generated secrets, and default values.

This ensures that the source of truth for configuration is clear, and customization is handled through override files without modifying the core templates.

---

## Phase 1: Schema Generation

-   **Trigger**: This phase runs automatically during the build process (`scripts/build.sh`).
-   **Script**: `scripts/build/env/build_env_schema_yaml.sh`
-   **Input**: Template files located at `src/env/.env.*.tpl`.
-   **Output**: A schema file named `vars.yaml` inside the release root's `env/` directory (e.g., `build/env/vars.yaml` or `dist/env/vars.yaml`).

### How it Works

The script parses each `.tpl` file and builds a corresponding section in `vars.yaml`. For each variable (`VAR=default #required`), it extracts:

-   **`required`**: `true` if the line contains the comment `#required`, otherwise `false`.
-   **`default`**: The value assigned in the template (e.g., `default` in `VAR=default`).
-   **`alias`**: If the default value is a reference to another variable (e.g., `PG_USER=$POSTGRES_USER`), it records an alias for later resolution.
-   **`generate`**: `true` if the variable is a known secret that should be auto-generated (e.g., `N8N_ENCRYPTION_KEY`). The generation `type` (e.g., `random_base64_32`) is also recorded.

**Example Flow**:
`src/env/.env.postgres.tpl` containing `POSTGRES_PASSWORD= #required` becomes a `postgres` section in `vars.yaml` with a `POSTGRES_PASSWORD` key marked as `required: true` and `generate: true`.

---

## Phase 2: Environment Rendering

-   **Trigger**: This phase is typically called by the `setup.sh` script within a release artifact.
-   **Script**: `scripts/render_env.sh` (inside the release artifact, e.g., `build/scripts/render_env.sh`).
-   **Input**: The `vars.yaml` schema generated in Phase 1.
-   **Output**: Final, usable environment files in the release root's `env/` directory (e.g., `build/env/.env.postgres`).

### Value Precedence Order

The rendering script determines the final value for each variable in the following order of priority (highest first):

1.  **User Override**: The value is taken from an override `.env` file if present. The script searches for an override file in several locations, with the highest priority being a `.env` file in the release root (e.g., `build/.env`). This is the **recommended way to customize your deployment**.

2.  **Generated Secret**: If the variable is marked for generation in `vars.yaml` and was not overridden, a cryptographically secure value is generated.

3.  **Default Value**: If the variable was not overridden or generated, the `default` value from `vars.yaml` is used.

4.  **Alias Resolution**: If a value is an alias (e.g., `$POSTGRES_USER`), it is replaced with the final resolved value of the referenced variable.

### Secret Persistence

To ensure stability across development rebuilds, the rendering script includes a special rule: if `PG_DB_PASSWORD` is not provided in an override file, the script will attempt to reuse the value from a previously generated `build/env/.env.postgres` file. This prevents the database password from changing on every build, which would break the connection with n8n.

### How to Provide Custom Values

To customize your deployment (e.g., set a specific domain name or use an existing database password), create a `.env` file in the root of your release directory (`build/` or `dist/`) and define your variables there.

**Example `build/.env`**:

```env
# Custom domain for n8n
N8N_HOST=n8n.mycompany.com

# Email for Let's Encrypt SSL certificates
CERTBOT_EMAIL=admin@mycompany.com

# Use an existing Postgres password
PG_DB_PASSWORD=my-secure-existing-password
```

These values will override any defaults or secret generation rules during the rendering phase.
