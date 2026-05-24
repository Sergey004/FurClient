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

const USER_AGENT = 'FurClientRN/1.0';

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
  const headers: Record<string, string> = {
    'User-Agent': USER_AGENT,
  };
  if (session?.cookies) {
    headers['Cookie'] = cookieHeader(session);
  }

  const response = await fetch(url, {headers});
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
      'User-Agent': USER_AGENT,
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
    const headers: Record<string, string> = {
      'User-Agent': USER_AGENT,
    };
    if (this.session?.cookies) {
      headers['Cookie'] = cookieHeader(this.session);
    }

    const response = await fetch(url, {headers});
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    return response.text();
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
