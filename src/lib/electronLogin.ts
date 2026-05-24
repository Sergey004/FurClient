import {UserSession} from '../types';

interface ElectronAPI {
  openLoginWindow: () => Promise<UserSession | null>;
}

declare global {
  interface Window {
    electronAPI?: ElectronAPI;
  }
}

export function isElectron(): boolean {
  return typeof window !== 'undefined' && !!window.electronAPI;
}

export async function electronLogin(): Promise<UserSession | null> {
  if (!window.electronAPI) return null;
  return window.electronAPI.openLoginWindow();
}
