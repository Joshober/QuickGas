# Deployment Guide for QuickGas Backend

## Option 1: Render (Free Tier - Recommended)

### Steps:
1. **Create Render Account**
   - Go to [render.com](https://render.com)
   - Sign up for free

2. **Create Web Service**
   - Click "New +" → "Web Service"
   - Connect your Git repository
   - Or deploy from the `backend` folder

3. **Configure Service**
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
   - **Environment**: `Node`

4. **Set Environment Variables** (in Render dashboard):
   ```
   NODE_ENV=production
   STRIPE_SECRET_KEY=sk_test_...
   FIREBASE_SERVICE_ACCOUNT={"type":"service_account",...}
   OPENROUTESERVICE_API_KEY=...
   ```

5. **Deploy!**
   - Render will auto-deploy on git push
   - Your backend URL will be: `https://your-app-name.onrender.com`

### Free Tier Limits:
- 512MB RAM (sufficient for ~100 users)
- 750 hours/month (plenty for always-on)
- Free SSL
- Spins down after 15min inactivity (takes ~30s to wake)

**Cost: $0/month for small apps**

---

## Option 2: Railway ($5/month credit)

### Steps:
1. **Create Railway Account**
   - Go to [railway.app](https://railway.app)
   - Sign up (free trial with $5 credit)

2. **Create Project**
   - Click "New Project"
   - Select "Deploy from GitHub repo"

3. **Add Environment Variables**
   - Same as Render above

4. **Deploy**
   - Railway auto-detects Node.js
   - Deploys automatically

### Pricing:
- $5/month credit (enough for small apps)
- After credit: ~$5-10/month
- No spin-down, always on

**Cost: $0-5/month (with credit, then ~$5/month)**

---

## Option 3: Fly.io (Free Tier)

### Steps:
1. **Install Fly CLI**
   ```bash
   curl -L https://fly.io/install.sh | sh
   ```

2. **Login**
   ```bash
   fly auth login
   ```

3. **Initialize App**
   ```bash
   cd backend
   fly launch
   ```

4. **Set Secrets**
   ```bash
   fly secrets set STRIPE_SECRET_KEY=sk_test_...
   fly secrets set FIREBASE_SERVICE_ACCOUNT='{"type":...}'
   ```

5. **Deploy**
   ```bash
   fly deploy
   ```

### Free Tier:
- 3 shared-cpu-1x VMs
- 256MB RAM per VM
- 3GB persistent volume
- Perfect for small apps

**Cost: $0/month**

---

## Recommendation for < 50 Users

**Use Render's free tier:**
- Free
- Easy setup
- Auto-deploys from Git
- Good documentation
- 15min spin-down (acceptable for small apps)

**Or use Fly.io if you prefer:**
- Free
- Always on
- More control
- Requires CLI setup

---

## Getting Firebase Service Account JSON

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to **Project Settings** → **Service Accounts**
4. Click **Generate New Private Key**
5. Download the JSON file
6. Copy the entire JSON content
7. Paste it as a single line in environment variable `FIREBASE_SERVICE_ACCOUNT`

**Important**: Keep this JSON secure! Never commit it to Git.

---

## Testing Your Backend

Once deployed, test with:

```bash
# Health check
curl https://your-backend-url.onrender.com/health

# Should return: {"status":"ok","timestamp":"..."}
```

---

## Update Flutter App

In `lib/core/constants/backend_constants.dart`, set:
```dart
static const String backendUrl = 'https://your-app-name.onrender.com';
```

Or build with:
```bash
flutter run --dart-define=BACKEND_URL=https://your-app-name.onrender.com
```

