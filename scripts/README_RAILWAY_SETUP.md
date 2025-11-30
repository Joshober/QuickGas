# Railway Environment Setup Scripts

These scripts automatically read your `.env` file and configure Railway environment variables, keeping your API keys secure and out of chat logs.

## Scripts

### `setup-railway-all.ps1`
**Recommended**: Sets up both backend and frontend in one go.
```powershell
.\scripts\setup-railway-all.ps1
```

### `setup-railway-backend.ps1`
Sets up only the backend service environment variables.
```powershell
.\scripts\setup-railway-backend.ps1
```

### `setup-railway-frontend.ps1`
Sets up only the frontend service environment variables.
```powershell
.\scripts\setup-railway-frontend.ps1
```

## What These Scripts Do

### Backend Setup
- Reads `.env` file from project root
- Sets the following variables in Railway backend service:
  - `STRIPE_SECRET_KEY`
  - `FIREBASE_SERVICE_ACCOUNT` (handles multi-line JSON)
  - `FIREBASE_ENABLED` (auto-set to `true` if Firebase config exists)
  - `OPENROUTESERVICE_API_KEY`
  - `DATABASE_URL` (from PostgreSQL service, using internal networking)
  - `DATABASE_USERNAME` (from PostgreSQL service)
  - `DATABASE_PASSWORD` (from PostgreSQL service)
  - `CORS_ALLOWED_ORIGINS` (auto-detected from frontend service)
  - `SERVER_BASE_URL` (auto-detected from backend service)

### Frontend Setup
- Reads `.env` file from project root
- Sets the following variables in Railway frontend service:
  - `GOOGLE_MAPS_API_KEY`
  - `STRIPE_PUBLISHABLE_KEY`
  - `BACKEND_URL` (auto-detected from backend service)

## Requirements

1. **Railway CLI installed and logged in**
   ```powershell
   railway login
   ```

2. **`.env` file in project root** with your API keys:
   ```env
   STRIPE_SECRET_KEY=sk_test_...
   STRIPE_PUBLISHABLE_KEY=pk_test_...
   GOOGLE_MAPS_API_KEY=...
   OPENROUTESERVICE_API_KEY=...
   FIREBASE_SERVICE_ACCOUNT={
     "project_info": {
       ...
     }
   }
   ```

3. **PostgreSQL service** already deployed in Railway (the script will auto-detect it)

## Usage

1. Make sure you're logged into Railway:
   ```powershell
   railway whoami
   ```

2. Run the setup script:
   ```powershell
   .\scripts\setup-railway-all.ps1
   ```

3. The script will:
   - Link to the appropriate Railway services
   - Read your `.env` file
   - Parse all environment variables (including multi-line JSON)
   - Set them in Railway
   - Configure database connection using internal networking
   - Auto-detect service URLs for CORS and backend URL

## Security Notes

- ✅ Your API keys are **never exposed** in chat or logs
- ✅ Scripts read directly from your local `.env` file
- ✅ Database uses Railway's internal networking (`.railway.internal`)
- ✅ All sensitive values are set securely via Railway CLI

## Troubleshooting

### Script fails to find .env file
- Make sure you're running from the project root, or the `.env` file is in the project root

### Railway CLI not found
- Install Railway CLI: `npm install -g @railway/cli`
- Or download from: https://railway.app/cli

### Service not found
- Make sure services are deployed in Railway first
- Check service names match: `backend`, `frontend`, `Postgres`

### Multi-line JSON not parsed correctly
- The script handles Firebase service account JSON automatically
- If issues persist, ensure the JSON in `.env` is properly formatted

## Verification

After running the scripts, verify the variables are set:

```powershell
# Check backend variables
cd backend-java
railway link --service backend
railway variables

# Check frontend variables
cd ..
railway link --service frontend
railway variables
```

## Re-running Scripts

You can safely re-run these scripts anytime:
- They will update existing variables
- Safe to run multiple times
- Won't duplicate variables

