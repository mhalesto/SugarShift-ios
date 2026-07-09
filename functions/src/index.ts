import { Buffer } from "node:buffer";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { importPKCS8, SignJWT } from "jose";

initializeApp();

const db = getFirestore();
const region = "europe-west1";
const appStoreBundleID = process.env.APP_STORE_BUNDLE_ID ?? "com.currenttech.SugarShift";
const productionStoreKitBaseURL = "https://api.storekit.apple.com";
const sandboxStoreKitBaseURL = "https://api.storekit-sandbox.apple.com";
const coinProductCoins: Record<string, number> = {
  "com.currenttech.SugarShift.coins.small": 500,
  "com.currenttech.SugarShift.coins.large": 5_000,
};
// Client progress sync intentionally excludes economy balances. Coins, stocked
// boosters, lives, piggy bank, and timed paid perks must not be authored by the
// client callable.
const progressKeys = new Set([
  "schemaVersion",
  "clientUpdatedAt",
  "currentLevel",
  "totalScore",
  "dailyRewardDate",
  "dailyAdBonusDate",
  "dailyStreak",
  "unlockedThemes",
  "stars",
  "claimedRewards",
  "claimedThreeStarRewards",
  "claimedEventRewards",
  "claimedBossRewards",
  "medals",
  "ratings",
]);

type PlainRecord = Record<string, unknown>;
type AppStoreEnvironment = "Production" | "Sandbox" | "UnverifiedLocal";
type ValidatedStoreKitTransaction = {
  environment: AppStoreEnvironment;
  originalTransactionID: string | null;
  purchaseDate: number | null;
  signedDate: number | null;
};

class AppStoreAPIError extends Error {
  status: number;
  bodyText: string;
  errorCode: number | undefined;

  constructor(status: number, bodyText: string, errorCode: number | undefined) {
    super(`App Store Server API returned ${status}.`);
    this.status = status;
    this.bodyText = bodyText;
    this.errorCode = errorCode;
  }
}

async function requireUid(auth: { uid?: string } | undefined, data?: PlainRecord): Promise<string> {
  if (!auth?.uid) {
    const token = typeof data?.authIDToken === "string" ? data.authIDToken.trim() : "";
    if (!token) {
      throw new HttpsError("unauthenticated", "Sign in is required.");
    }

    try {
      const decoded = await getAuth().verifyIdToken(token);
      return decoded.uid;
    } catch {
      throw new HttpsError("unauthenticated", "Sign in is required.");
    }
  }
  return auth.uid;
}

function assertRecord(value: unknown, label: string): PlainRecord {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", `${label} must be an object.`);
  }
  return value as PlainRecord;
}

function stringValue(data: PlainRecord, key: string): string {
  const value = data[key];
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${key} is required.`);
  }
  return value.trim();
}

function numberValue(data: PlainRecord, key: string, min = 0, max = 1_000_000): number {
  const value = data[key];
  if (typeof value !== "number" || !Number.isFinite(value) || value < min || value > max) {
    throw new HttpsError("invalid-argument", `${key} is invalid.`);
  }
  return Math.floor(value);
}

function optionalString(data: PlainRecord, key: string): string | null {
  const value = data[key];
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : null;
}

function optionalNumber(data: PlainRecord, key: string): number | null {
  const value = data[key];
  return typeof value === "number" && Number.isFinite(value) ? Math.floor(value) : null;
}

function envValue(keys: string[]): string | undefined {
  for (const key of keys) {
    const value = process.env[key];
    if (value && value.trim().length > 0) {
      return value.trim();
    }
  }
  return undefined;
}

function appStoreCredentials(): { issuerID: string; keyID: string; privateKey: string } {
  const issuerID = envValue(["APP_STORE_CONNECT_ISSUER_ID", "APP_STORE_ISSUER_ID"]);
  const keyID = envValue(["APP_STORE_CONNECT_KEY_ID", "APP_STORE_KEY_ID"]);
  const rawPrivateKey = envValue(["APP_STORE_CONNECT_PRIVATE_KEY", "APP_STORE_PRIVATE_KEY"]);

  if (!issuerID || !keyID || !rawPrivateKey) {
    throw new HttpsError(
      "failed-precondition",
      "App Store Server API credentials are not configured for StoreKit delivery validation.",
    );
  }

  return {
    issuerID,
    keyID,
    privateKey: rawPrivateKey.replace(/\\n/g, "\n"),
  };
}

async function appStoreAuthToken(): Promise<string> {
  const credentials = appStoreCredentials();
  const privateKey = await importPKCS8(credentials.privateKey, "ES256");

  return new SignJWT({ bid: appStoreBundleID })
    .setProtectedHeader({ alg: "ES256", kid: credentials.keyID, typ: "JWT" })
    .setIssuer(credentials.issuerID)
    .setAudience("appstoreconnect-v1")
    .setIssuedAt()
    .setExpirationTime("5m")
    .sign(privateKey);
}

function decodeBase64URL(value: string): string {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(normalized.length + ((4 - (normalized.length % 4)) % 4), "=");
  return Buffer.from(padded, "base64").toString("utf8");
}

function decodeJWSPayload(signedPayload: string): PlainRecord {
  const parts = signedPayload.split(".");
  if (parts.length !== 3) {
    throw new HttpsError("permission-denied", "App Store transaction payload is invalid.");
  }

  try {
    return assertRecord(JSON.parse(decodeBase64URL(parts[1])), "App Store transaction payload");
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("permission-denied", "App Store transaction payload could not be decoded.");
  }
}

function readAppStoreErrorCode(bodyText: string): number | undefined {
  try {
    const body = assertRecord(JSON.parse(bodyText), "App Store error response");
    const rawCode = body.errorCode;
    return typeof rawCode === "number" && Number.isFinite(rawCode) ? rawCode : undefined;
  } catch {
    return undefined;
  }
}

async function fetchAppStoreTransactionPayload(
  transactionID: string,
  baseURL: string,
  environment: Exclude<AppStoreEnvironment, "UnverifiedLocal">,
  token: string,
): Promise<{ environment: AppStoreEnvironment; payload: PlainRecord }> {
  const response = await fetch(
    `${baseURL}/inApps/v1/transactions/${encodeURIComponent(transactionID)}`,
    { headers: { Authorization: `Bearer ${token}` } },
  );
  const bodyText = await response.text();

  if (!response.ok) {
    throw new AppStoreAPIError(response.status, bodyText, readAppStoreErrorCode(bodyText));
  }

  let body: PlainRecord;
  try {
    body = assertRecord(JSON.parse(bodyText), "App Store transaction response");
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("permission-denied", "App Store transaction response could not be decoded.");
  }

  const signedTransactionInfo = body.signedTransactionInfo;
  if (typeof signedTransactionInfo !== "string" || signedTransactionInfo.length === 0) {
    throw new HttpsError("permission-denied", "App Store transaction response did not include transaction info.");
  }

  return { environment, payload: decodeJWSPayload(signedTransactionInfo) };
}

async function fetchAppStoreTransaction(
  transactionID: string,
): Promise<{ environment: AppStoreEnvironment; payload: PlainRecord }> {
  const token = await appStoreAuthToken();

  try {
    return await fetchAppStoreTransactionPayload(transactionID, productionStoreKitBaseURL, "Production", token);
  } catch (error) {
    if (error instanceof AppStoreAPIError && (error.status === 404 || error.errorCode === 4040010)) {
      return fetchAppStoreTransactionPayload(transactionID, sandboxStoreKitBaseURL, "Sandbox", token);
    }
    throw error;
  }
}

function validateExpectedCoinProduct(productID: string, coins: number): void {
  const expectedCoins = coinProductCoins[productID];
  if (expectedCoins !== coins) {
    throw new HttpsError("invalid-argument", "StoreKit product reward is not recognized.");
  }
}

async function validateStoreKitDelivery(
  transactionID: string,
  productID: string,
  coins: number,
): Promise<ValidatedStoreKitTransaction> {
  validateExpectedCoinProduct(productID, coins);

  if (process.env.ALLOW_UNVERIFIED_STOREKIT_DELIVERY === "true") {
    return {
      environment: "UnverifiedLocal",
      originalTransactionID: null,
      purchaseDate: null,
      signedDate: null,
    };
  }

  const transaction = await fetchAppStoreTransaction(transactionID);
  const payload = transaction.payload;
  const appStoreTransactionID = optionalString(payload, "transactionId");
  const appStoreProductID = optionalString(payload, "productId");
  const appStorePayloadBundleID = optionalString(payload, "bundleId");
  const appStoreType = optionalString(payload, "type");

  if (appStoreTransactionID !== transactionID) {
    throw new HttpsError("permission-denied", "StoreKit transaction ID did not match App Store records.");
  }
  if (appStoreProductID !== productID) {
    throw new HttpsError("permission-denied", "StoreKit product ID did not match App Store records.");
  }
  if (appStorePayloadBundleID !== appStoreBundleID) {
    throw new HttpsError("permission-denied", "StoreKit bundle ID did not match this app.");
  }
  if (appStoreType && appStoreType.toLowerCase() !== "consumable") {
    throw new HttpsError("permission-denied", "StoreKit transaction was not for a consumable product.");
  }
  if (payload.revocationDate !== undefined || payload.revocationReason !== undefined) {
    throw new HttpsError("permission-denied", "StoreKit transaction has been revoked.");
  }

  return {
    environment: transaction.environment,
    originalTransactionID: optionalString(payload, "originalTransactionId"),
    purchaseDate: optionalNumber(payload, "purchaseDate"),
    signedDate: optionalNumber(payload, "signedDate"),
  };
}

function sanitizeMap(value: unknown, valueType: "number" | "boolean", maxNumber = 1_000_000): PlainRecord {
  const input = assertRecord(value, "map");
  const output: PlainRecord = {};
  for (const [key, raw] of Object.entries(input)) {
    if (!/^[A-Za-z0-9_.-]{1,64}$/.test(key)) {
      continue;
    }
    if (valueType === "number" && typeof raw === "number" && Number.isFinite(raw)) {
      output[key] = Math.max(0, Math.min(maxNumber, Math.floor(raw)));
    }
    if (valueType === "boolean" && typeof raw === "boolean") {
      output[key] = raw;
    }
  }
  return output;
}

function sanitizeStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return [...new Set(value.filter((item): item is string => typeof item === "string"))]
    .map((item) => item.trim())
    .filter((item) => item.length > 0 && item.length <= 128)
    .slice(0, 500)
    .sort();
}

function sanitizeProgress(rawState: unknown): PlainRecord {
  const input = assertRecord(rawState, "state");
  const output: PlainRecord = {};

  for (const [key, value] of Object.entries(input)) {
    if (!progressKeys.has(key)) {
      continue;
    }

    switch (key) {
    case "unlockedThemes":
      output[key] = sanitizeStringArray(value);
      break;
    case "stars":
      output[key] = sanitizeMap(value, "number", 3);
      break;
    case "medals":
      output[key] = sanitizeMap(value, "number", 7);
      break;
    case "ratings":
      output[key] = sanitizeMap(value, "number", 3);
      break;
    case "claimedRewards":
    case "claimedThreeStarRewards":
    case "claimedEventRewards":
    case "claimedBossRewards":
      output[key] = sanitizeMap(value, "boolean");
      break;
    case "dailyRewardDate":
    case "dailyAdBonusDate":
      if (typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value)) {
        output[key] = value;
      }
      break;
    case "lifeReferenceAt":
    case "coinDoublerExpiresAt":
      if (typeof value === "number" && Number.isFinite(value)) {
        output[key] = value;
      }
      break;
    default:
      if (typeof value === "number" && Number.isFinite(value)) {
        output[key] = Math.max(0, Math.floor(value));
      }
    }
  }

  output.schemaVersion = 1;
  output.serverUpdatedAt = FieldValue.serverTimestamp();
  return output;
}

export const syncProgress = onCall({ region }, async (request) => {
  const data = assertRecord(request.data, "payload");
  const uid = await requireUid(request.auth, data);
  const progress = sanitizeProgress(data.state);

  await db.doc(`users/${uid}/state/progress`).set(progress, { merge: true });
  await db.doc(`users/${uid}`).set({
    updatedAt: FieldValue.serverTimestamp(),
    lastClientUpdatedAt: progress.clientUpdatedAt ?? null,
  }, { merge: true });

  return { ok: true };
});

export const pullProgress = onCall({ region }, async (request) => {
  const data = assertRecord(request.data ?? {}, "payload");
  const uid = await requireUid(request.auth, data);
  const snapshot = await db.doc(`users/${uid}/state/progress`).get();

  return { ok: true, state: snapshot.exists ? snapshot.data() ?? {} : {} };
});

export const recordStoreKitDelivery = onCall({ region }, async (request) => {
  const data = assertRecord(request.data, "payload");
  const uid = await requireUid(request.auth, data);
  const transactionID = stringValue(data, "transactionID");
  const productID = stringValue(data, "productID");
  const coins = numberValue(data, "coins", 1, 100_000);
  const clientUpdatedAt = typeof data.clientUpdatedAt === "number" ? data.clientUpdatedAt : null;
  const progressUpdatedAt = clientUpdatedAt ?? Date.now() / 1000;
  const appStoreValidation = await validateStoreKitDelivery(transactionID, productID, coins);
  const transactionRef = db.doc(`users/${uid}/storeKitTransactions/${transactionID}`);
  const globalTransactionRef = db.doc(`storeKitTransactions/${transactionID}`);
  const progressRef = db.doc(`users/${uid}/state/progress`);
  const progressCredit = {
    schemaVersion: 1,
    clientUpdatedAt: progressUpdatedAt,
    serverUpdatedAt: FieldValue.serverTimestamp(),
    deliveredStoreKitTransactionIDs: FieldValue.arrayUnion(transactionID),
    storeKitCoinCredits: {
      [transactionID]: coins,
    },
  };
  const userUpdate = {
    updatedAt: FieldValue.serverTimestamp(),
    lastStoreKitDeliveryAt: FieldValue.serverTimestamp(),
  };

  let alreadyRecorded = false;
  await db.runTransaction(async (transaction) => {
    const [existingUserRecord, existingGlobalRecord] = await Promise.all([
      transaction.get(transactionRef),
      transaction.get(globalTransactionRef),
    ]);
    if (existingUserRecord.exists || existingGlobalRecord.exists) {
      const globalData = existingGlobalRecord.data();
      const globalOwnerUid = typeof globalData?.uid === "string" ? globalData.uid : null;
      if (existingGlobalRecord.exists && globalOwnerUid !== uid) {
        throw new HttpsError("permission-denied", "StoreKit transaction was already delivered.");
      }

      alreadyRecorded = true;
      if (!existingUserRecord.exists) {
        transaction.set(transactionRef, {
          uid,
          productID,
          coins,
          clientUpdatedAt,
          appStore: appStoreValidation,
          recordedAt: FieldValue.serverTimestamp(),
        });
      }
      if (!existingGlobalRecord.exists) {
        transaction.set(globalTransactionRef, {
          uid,
          productID,
          coins,
          clientUpdatedAt,
          appStore: appStoreValidation,
          recordedAt: FieldValue.serverTimestamp(),
        });
      }
      transaction.set(progressRef, progressCredit, { merge: true });
      transaction.set(db.doc(`users/${uid}`), userUpdate, { merge: true });
      return;
    }

    const ledgerRecord = {
      uid,
      productID,
      coins,
      clientUpdatedAt,
      appStore: appStoreValidation,
      recordedAt: FieldValue.serverTimestamp(),
    };

    transaction.set(globalTransactionRef, ledgerRecord);
    transaction.set(transactionRef, ledgerRecord);
    transaction.set(progressRef, progressCredit, { merge: true });
    transaction.set(db.doc(`users/${uid}`), userUpdate, { merge: true });
  });

  return { ok: true, alreadyRecorded };
});
