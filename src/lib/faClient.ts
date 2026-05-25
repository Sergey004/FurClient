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

const FA_UA = 'ceylo.FurAffinityApp/1.0';

const BASE_HEADERS: Record<string, string> = {
  'User-Agent': FA_UA,
};

class CloudflareError extends Error {
  constructor() {
    super('FA is currently protected by Cloudflare challenge. Please try again later.');
    this.name = 'CloudflareError';
  }
}

function checkCloudflare(response: Response): void {
  if (response.headers.get('cf-mitigated') === 'challenge') {
    throw new CloudflareError();
  }
}

async function fetchHtml(url: string, session?: UserSession): Promise<string> {
  const headers: Record<string, string> = {...BASE_HEADERS};
  const response = await fetch(url, {headers, credentials: 'include'});
  checkCloudflare(response);
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
      'User-Agent': FA_UA,
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
    const headers: Record<string, string> = {...BASE_HEADERS};
    const response = await fetch(url, {headers, credentials: 'include'});
    checkCloudflare(response);
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
