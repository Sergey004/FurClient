import {UserSession} from '../types';

const SESSION_KEY = 'fa_session';

function isBrowser(): boolean {
  return typeof window !== 'undefined' && typeof (window as any).document !== 'undefined';
}

interface SimpleStorage {
  getItem(key: string): Promise<string | null>;
  setItem(key: string, value: string): Promise<void>;
  removeItem(key: string): Promise<void>;
}

async function getStorage(): Promise<SimpleStorage | null> {
  try {
    const AsyncStorage = require('@react-native-async-storage/async-storage').default;
    if (AsyncStorage) return AsyncStorage;
  } catch {}
  if (isBrowser()) {
    return {
      getItem: async (key: string) => localStorage.getItem(key),
      setItem: async (key: string, value: string) => {
        localStorage.setItem(key, value);
      },
      removeItem: async (key: string) => localStorage.removeItem(key),
    };
  }
  return null;
}

export async function loadSession(): Promise<UserSession | null> {
  try {
    const storage = await getStorage();
    if (!storage) return null;
    const data = await storage.getItem(SESSION_KEY);
    if (data) {
      return JSON.parse(data);
    }
  } catch {}
  return null;
}

export async function saveSession(session: UserSession): Promise<void> {
  try {
    const storage = await getStorage();
    if (storage) {
      await storage.setItem(SESSION_KEY, JSON.stringify(session));
    }
  } catch {}
}

export async function clearSession(): Promise<void> {
  try {
    const storage = await getStorage();
    if (storage) {
      await storage.removeItem(SESSION_KEY);
    }
  } catch {}
}
