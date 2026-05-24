import {UserSession, Submission, Comment, FANotification, FAUser} from '../types';
import {FAUrls} from './faUrls';
import {
  parseSubmissionsPage,
  parseSubmissionDetails,
  parseComments,
  parseNotifications,
  parseUserPage,
  parseSearchResults,
} from './faParser';

const CHROME_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

const BASE_HEADERS: Record<string, string> = {
  'User-Agent': CHROME_UA,
  'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
  'Accept-Language': 'en-US,en;q=0.5',
};

function cookieHeader(session: UserSession): string {
  if (session.cookies) {
    try {
      const pairs = JSON.parse(session.cookies);
      if (Array.isArray(pairs)) {
        return pairs.map(([k, v]: [string, string]) => `${k}=${v}`).join('; ');
      }
    } catch {}
  }
  return '';
}

async function fetchHtml(url: string, session?: UserSession): Promise<string> {
  const cookieString = session?.cookies ? cookieHeader(session) : '';
  const ep = typeof window !== 'undefined' ? (window as any).electronAPI : undefined;

  if (ep?.faFetch) {
    const result = await ep.faFetch(url, cookieString);
    if (result.error) throw new Error(result.error);
    return result.html!;
  }

  const headers: Record<string, string> = {...BASE_HEADERS};
  if (cookieString) headers['Cookie'] = cookieString;

  const response = await fetch(url, {headers, credentials: 'include'});
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
  }
  return response.text();
}

function extractCookiesFromResponse(headers: Headers): string | null {
  const setCookie = headers.get('set-cookie');
  if (!setCookie) return null;

  const cookies = setCookie.split(/,(?=\s*\w+=)/);
  const pairs: [string, string][] = cookies.map(c => {
    const [keyVal] = c.split(';')[0].split('=');
    const val = c.split(';')[0].split('=').slice(1).join('=');
    return [keyVal.trim(), val.trim()];
  });
  return JSON.stringify(pairs);
}

export async function loginToFA(username: string, password: string): Promise<UserSession | null> {
  const formData = new URLSearchParams();
  formData.append('login', username);
  formData.append('password', password);
  formData.append('return', '/');

  const response = await fetch(`${FAUrls.login}/`, {
    method: 'POST',
    headers: {
      'User-Agent': CHROME_UA,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: formData.toString(),
    redirect: 'manual',
  });

  if (response.ok || response.status === 302) {
    const cookies = extractCookiesFromResponse(response.headers);
    if (cookies) {
      const session: UserSession = {
        username,
        avatarUrl: FAUrls.avatar(username),
        isLoggedIn: true,
        cookies,
      };
      return session;
    }
  }

  return null;
}

export async function fetchUserSession(username: string, password: string): Promise<UserSession | null> {
  return loginToFA(username, password);
}

export class FAClient {
  private session: UserSession | null;

  constructor(session: UserSession | null) {
    this.session = session;
  }

  setSession(session: UserSession | null) {
    this.session = session;
  }

  private async getHtml(url: string): Promise<string> {
    const cookieString = this.session?.cookies ? cookieHeader(this.session) : '';
    const ep = typeof window !== 'undefined' ? (window as any).electronAPI : undefined;

    if (ep?.faFetch) {
      const result = await ep.faFetch(url, cookieString);
      if (result.error) throw new Error(result.error);
      return result.html!;
    }

    const headers: Record<string, string> = {...BASE_HEADERS};
    if (cookieString) headers['Cookie'] = cookieString;

    const response = await fetch(url, {headers, credentials: 'include'});
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    return response.text();
  }

  async verifySession(): Promise<boolean> {
    if (!this.session?.cookies) return false;
    try {
      await this.getHtml('https://www.furaffinity.net/');
      return true;
    } catch { return false; }
  }

  async getSubmissions(page: number = 1, filter: string = 'all'): Promise<Submission[]> {
    const url = FAUrls.browse(filter, page);
    const html = await this.getHtml(url);
    return parseSubmissionsPage(html);
  }

  async getSubmission(id: string): Promise<Submission | null> {
    const url = FAUrls.viewSubmission(id);
    const html = await this.getHtml(url);
    return parseSubmissionDetails(html, id);
  }

  async getComments(id: string): Promise<Comment[]> {
    const url = FAUrls.viewSubmission(id);
    const html = await this.getHtml(url);
    return parseComments(html);
  }

  async search(query: string, page: number = 1): Promise<Submission[]> {
    const url = FAUrls.search(query, page);
    const html = await this.getHtml(url);
    return parseSearchResults(html);
  }

  async getNotifications(): Promise<FANotification[]> {
    const url = FAUrls.notifications;
    const html = await this.getHtml(url);
    return parseNotifications(html);
  }

  async getUser(username: string): Promise<FAUser | null> {
    const url = FAUrls.user(username);
    const html = await this.getHtml(url);
    return parseUserPage(html, username);
  }
}
