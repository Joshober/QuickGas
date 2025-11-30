# Railway Deployment Setup Summary

## ✅ Completed Configuration

### Services Deployed
1. **Backend Service** (Java Spring Boot)
   - Service Name: `backend`
   - URL: https://backend-production-d2008.up.railway.app
   - Status: Deployed

2. **Frontend Service** (Flutter Web)
   - Service Name: `frontend`
   - URL: https://frontend-production-17c3.up.railway.app
   - Status: Deployed

3. **PostgreSQL Database**
   - Status: Deployed (as mentioned by user)
   - Note: May need to be linked to backend service

### Environment Variables Configured

#### Backend Service
- ✅ `CORS_ALLOWED_ORIGINS`: https://frontend-production-17c3.up.railway.app
- ✅ `SERVER_BASE_URL`: https://backend-production-d2008.up.railway.app
- ⚠️ `DATABASE_URL`: Needs to be set (from PostgreSQL service)
- ⚠️ `DATABASE_USERNAME`: Needs to be set
- ⚠️ `DATABASE_PASSWORD`: Needs to be set
- ⚠️ `STRIPE_SECRET_KEY`: Needs to be set by user
- ⚠️ `FIREBASE_SERVICE_ACCOUNT`: Needs to be set by user (JSON string)
- ⚠️ `FIREBASE_ENABLED`: Set to `true` if using Firebase
- ⚠️ `OPENROUTESERVICE_API_KEY`: Optional, set if using route optimization

#### Frontend Service
- ✅ `BACKEND_URL`: https://backend-production-d2008.up.railway.app
- ⚠️ `GOOGLE_MAPS_API_KEY`: Needs to be set by user
- ⚠️ `STRIPE_PUBLISHABLE_KEY`: Needs to be set by user
- ⚠️ Firebase configuration variables (if using Firebase)

## ✅ Recent Fixes

- Fixed compilation errors in `PaymentService.java` (Stripe API method calls)
- Fixed missing `Map` import in `PaymentController.java`
- Backend is now redeploying with fixes

## 🔧 Next Steps

### 1. Link PostgreSQL Database to Backend
If the database is not automatically linked, you need to:
- Go to Railway dashboard → vocal-ship project
- Find the PostgreSQL service
- Link it to the backend service
- This will automatically create `DATABASE_URL`, `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE` variables

Alternatively, if you have the database connection details, set them manually:
```bash
cd backend-java
railway variables --set "DATABASE_URL=jdbc:postgresql://host:port/database"
railway variables --set "DATABASE_USERNAME=username"
railway variables --set "DATABASE_PASSWORD=password"
```

### 2. Set Required API Keys

#### Backend API Keys
```bash
cd backend-java
railway variables --set "STRIPE_SECRET_KEY=sk_live_..." # or sk_test_... for testing
railway variables --set "FIREBASE_ENABLED=true" # if using Firebase
railway variables --set "FIREBASE_SERVICE_ACCOUNT={\"type\":\"service_account\",...}" # Firebase service account JSON
```

#### Frontend API Keys
```bash
cd .. # back to project root
railway link --service frontend
railway variables --set "GOOGLE_MAPS_API_KEY=your_google_maps_key"
railway variables --set "STRIPE_PUBLISHABLE_KEY=pk_live_..." # or pk_test_... for testing
```

### 3. Verify Deployments

Check service health:
```bash
# Backend health check
curl https://backend-production-d2008.up.railway.app/health

# Frontend
curl https://frontend-production-17c3.up.railway.app
```

### 4. View Logs
```bash
# Backend logs
cd backend-java
railway logs

# Frontend logs
cd ..
railway link --service frontend
railway logs
```

## 📝 Important Notes

1. **CORS Configuration**: The backend is configured to allow requests from the frontend URL. If you add more frontend domains, update `CORS_ALLOWED_ORIGINS` with comma-separated values.

2. **Database Migrations**: The backend uses Flyway for database migrations. Migrations will run automatically on startup if `DATABASE_URL` is set correctly.

3. **Environment Variables**: Some sensitive variables (like API keys) need to be set manually. Never commit these to version control.

4. **Service URLs**: Both services have public domains. Make sure to update your Flutter app configuration if needed.

## 🔗 Service URLs

- **Backend API**: https://backend-production-d2008.up.railway.app
- **Frontend Web App**: https://frontend-production-17c3.up.railway.app

## 🛠️ Railway CLI Commands Reference

```bash
# Link to a service
railway link --project vocal-ship --service <service-name>

# View variables
railway variables

# Set variables
railway variables --set "KEY=value"

# View logs
railway logs

# Check status
railway status

# Get service domain
railway domain --service <service-name>
```

