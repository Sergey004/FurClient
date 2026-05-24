import express, { Request, Response } from 'express';
import axios from 'axios';
import * as cheerio from 'cheerio';
import NodeCache from 'node-cache';

const router = express.Router();
const cache = new NodeCache({ stdTTL: 3600 }); // 1 hour cache

// Types
export interface Submission {
  id: string;
  title: string;
  author: string;
  category: 'Digital' | 'Writing' | 'Traditional';
  imageUrl: string;
  views: number;
  faves: number;
  commentsCount: number;
  description: string;
  tags: string[];
  date: string;
  isNsfw: boolean;
  url: string;
}

export interface Comment {
  id: string;
  author: string;
  avatarUrl: string;
  text: string;
  time: string;
}

export interface FANotification {
  id: string;
  author: string;
  avatarUrl: string;
  title: string;
  type: 'fave' | 'comment' | 'watch' | 'journal';
  datetime: string;
  url: string;
}

export interface UserSession {
  username: string;
  avatarUrl: string;
  isLoggedIn: boolean;
  cookies?: string;
}

// Парсер для Fur Affinity
class FAParser {
  private sessionCookies: Map<string, string> = new Map();
  private baseURL = 'https://www.furaffinity.net';

  constructor() {}

  async login(username: string, password: string): Promise<UserSession> {
    try {
      const response = await axios.post(`${this.baseURL}/user/login/`, {
        login: username,
        password: password,
        return: '/'
      }, {
        withCredentials: true,
        validateStatus: () => true // Accept all status codes
      });

      const isLoggedIn = response.status === 200 || response.status === 302;
      
      if (isLoggedIn) {
        // Extract cookies from response headers
        const setCookie = response.headers['set-cookie'];
        if (setCookie) {
          const cookieArray = Array.isArray(setCookie) ? setCookie : [setCookie];
          cookieArray.forEach(cookie => {
            const cookieName = cookie.split('=')[0];
            const cookieValue = cookie.split(';')[0].split('=')[1];
            this.sessionCookies.set(cookieName, cookieValue);
          });
        }

        const userSession: UserSession = {
          username,
          avatarUrl: await this.getUserAvatar(username),
          isLoggedIn: true,
          cookies: JSON.stringify(Array.from(this.sessionCookies.entries()))
        };
        cache.set(`session_${username}`, userSession, 86400); // 24 hours
        return userSession;
      }
    } catch (error) {
      console.error('Login error:', error);
    }

    return { username: '', avatarUrl: '', isLoggedIn: false };
  }

  async getSubmissions(page: number = 1, filter: 'all' | 'digital' | 'traditional' | 'writing' = 'all'): Promise<Submission[]> {
    const cacheKey = `submissions_${filter}_${page}`;
    const cached = cache.get(cacheKey) as Submission[] | undefined;
    if (cached) return cached;

    try {
      const filterMap = {
        'all': '',
        'digital': '?type=1',
        'traditional': '?type=2',
        'writing': '?type=3'
      };

      const url = `${this.baseURL}/browse/all/${filterMap[filter]}` + (page > 1 ? `&page=${page}` : '');
      const response = await axios.get(url, { withCredentials: true });
      const $ = cheerio.load(response.data);

      const submissions: Submission[] = [];

      $('div[id^="sid-"]').each((index, element) => {
        const $el = $(element);
        const id = $el.attr('id')?.replace('sid-', '') || '';
        const $link = $el.find('a[href*="/view/"]').first();
        const title = $link.attr('title') || $link.text() || 'Untitled';
        const url = $link.attr('href') || '';
        
        const author = $el.find('a[href*="/user/"]').first().text() || 'Unknown';
        const description = $el.find('.information').text() || '';
        
        const imageEl = $el.find('img[alt]').first();
        const imageUrl = imageEl.attr('src') || '';
        
        const statsText = $el.find('.stats-container, .grid-info').text();
        const views = parseInt(statsText.match(/(\d+)\s+views?/i)?.[1] || '0');
        const faves = parseInt(statsText.match(/(\d+)♥/)?.[1] || '0');
        
        const tagsText = $el.find('.tags').text();
        const tags = tagsText.split(',').map(t => t.trim().toLowerCase()).filter(t => t);

        const isNsfw = $el.find('[data-rating="adult"], [data-rating="mature"]').length > 0;

        if (id && title && url) {
          submissions.push({
            id,
            title,
            author,
            category: 'Digital',
            imageUrl,
            views,
            faves,
            commentsCount: 0,
            description,
            tags,
            date: new Date().toISOString(),
            isNsfw,
            url: `${this.baseURL}${url}`
          });
        }
      });

      cache.set(cacheKey, submissions);
      return submissions;
    } catch (error) {
      console.error('Error fetching submissions:', error);
      return [];
    }
  }

  async getSubmissionDetails(submissionId: string): Promise<Submission | null> {
    const cacheKey = `submission_${submissionId}`;
    const cached = cache.get(cacheKey) as Submission | undefined;
    if (cached) return cached;

    try {
      const url = `${this.baseURL}/view/${submissionId}/`;
      const response = await axios.get(url, { withCredentials: true });
      const $ = cheerio.load(response.data);

      const title = $('div.information h2').text() || 'Untitled';
      const author = $('a[href*="/user/"]').first().text() || 'Unknown';
      const description = $('div[class*="description"]').text() || '';
      const imageUrl = $('img[alt="Submission"]').attr('src') || '';
      const views = parseInt($('dt:contains("Views")').next().text() || '0');
      const faves = parseInt($('dt:contains("Favorites")').next().text() || '0');
      const commentsCount = parseInt($('dt:contains("Comments")').next().text() || '0');
      
      const tagsText = $('section.tags').text();
      const tags = tagsText.split(',').map(t => t.trim().toLowerCase()).filter(t => t);
      
      const isNsfw = $('[data-rating="adult"], [data-rating="mature"]').length > 0;
      const date = $('dt:contains("Posted")').next().text() || new Date().toISOString();

      const submission: Submission = {
        id: submissionId,
        title,
        author,
        category: 'Digital',
        imageUrl,
        views,
        faves,
        commentsCount,
        description,
        tags,
        date,
        isNsfw,
        url: `${this.baseURL}/view/${submissionId}/`
      };

      cache.set(cacheKey, submission);
      return submission;
    } catch (error) {
      console.error('Error fetching submission details:', error);
      return null;
    }
  }

  async getComments(submissionId: string): Promise<Comment[]> {
    const cacheKey = `comments_${submissionId}`;
    const cached = cache.get(cacheKey) as Comment[] | undefined;
    if (cached) return cached;

    try {
      const url = `${this.baseURL}/view/${submissionId}/`;
      const response = await axios.get(url, { withCredentials: true });
      const $ = cheerio.load(response.data);

      const comments: Comment[] = [];

      $('div[id^="cid-"]').each((index, element) => {
        const $el = $(element);
        const id = $el.attr('id')?.replace('cid-', '') || '';
        const author = $el.find('a[href*="/user/"]').first().text() || 'Anonymous';
        const avatarUrl = $el.find('img').first().attr('src') || '';
        const text = $el.find('div.comment-content').text() || '';
        const time = $el.find('span.popup_date').attr('title') || 'Unknown';

        comments.push({ id, author, avatarUrl, text, time });
      });

      cache.set(cacheKey, comments);
      return comments;
    } catch (error) {
      console.error('Error fetching comments:', error);
      return [];
    }
  }

  async getNotifications(username: string): Promise<FANotification[]> {
    const cacheKey = `notifications_${username}`;
    const cached = cache.get(cacheKey) as FANotification[] | undefined;
    if (cached) return cached;

    try {
      const url = `${this.baseURL}/notifications/`;
      const response = await axios.get(url, { withCredentials: true });
      const $ = cheerio.load(response.data);

      const notifications: FANotification[] = [];

      $('div[id^="notif-"]').each((index, element) => {
        const $el = $(element);
        const id = $el.attr('id') || '';
        const author = $el.find('a[href*="/user/"]').first().text() || 'Unknown';
        const avatarUrl = $el.find('img').first().attr('src') || '';
        const title = $el.text() || '';
        const type: any = 'fave';
        const datetime = $el.find('.popup_date').attr('title') || new Date().toISOString();
        const url = $el.find('a').first().attr('href') || '';

        notifications.push({
          id,
          author,
          avatarUrl,
          title,
          type,
          datetime,
          url: `${this.baseURL}${url}`
        });
      });

      cache.set(cacheKey, notifications);
      return notifications;
    } catch (error) {
      console.error('Error fetching notifications:', error);
      return [];
    }
  }

  async getUserAvatar(username: string): Promise<string> {
    try {
      const url = `${this.baseURL}/user/${username}/`;
      const response = await axios.get(url);
      const $ = cheerio.load(response.data);
      return $('img[alt="Avatar"]').attr('src') || '';
    } catch {
      return '';
    }
  }

  async searchSubmissions(query: string, page: number = 1): Promise<Submission[]> {
    const cacheKey = `search_${query}_${page}`;
    const cached = cache.get(cacheKey) as Submission[] | undefined;
    if (cached) return cached;

    try {
      const url = `${this.baseURL}/search/?q=${encodeURIComponent(query)}&page=${page}`;
      const response = await axios.get(url, { withCredentials: true });
      const $ = cheerio.load(response.data);

      const submissions: Submission[] = [];
      
      $('div[id^="sid-"]').each((index, element) => {
        const $el = $(element);
        const id = $el.attr('id')?.replace('sid-', '') || '';
        const $link = $el.find('a[href*="/view/"]').first();
        const title = $link.attr('title') || 'Untitled';
        const url = $link.attr('href') || '';
        const author = $el.find('a[href*="/user/"]').first().text() || 'Unknown';
        const imageUrl = $el.find('img').first().attr('src') || '';
        
        if (id && title) {
          submissions.push({
            id,
            title,
            author,
            category: 'Digital',
            imageUrl,
            views: 0,
            faves: 0,
            commentsCount: 0,
            description: '',
            tags: query.split(' '),
            date: new Date().toISOString(),
            isNsfw: false,
            url: `${this.baseURL}${url}`
          });
        }
      });

      cache.set(cacheKey, submissions);
      return submissions;
    } catch (error) {
      console.error('Error searching submissions:', error);
      return [];
    }
  }
}

const parser = new FAParser();

// API Routes
router.post('/auth/login', async (req: Request, res: Response) => {
  const { username, password } = req.body;
  if (!username || !password) {
    return res.status(400).json({ error: 'Username and password required' });
  }

  const session = await parser.login(username, password);
  if (session.isLoggedIn) {
    res.json(session);
  } else {
    res.status(401).json({ error: 'Login failed' });
  }
});

router.get('/submissions', async (req: Request, res: Response) => {
  const page = parseInt(req.query.page as string) || 1;
  const filter = (req.query.filter as string) || 'all';
  const submissions = await parser.getSubmissions(page, filter as any);
  res.json(submissions);
});

router.get('/submissions/:id', async (req: Request, res: Response) => {
  const submission = await parser.getSubmissionDetails(req.params.id);
  if (submission) {
    res.json(submission);
  } else {
    res.status(404).json({ error: 'Submission not found' });
  }
});

router.get('/submissions/:id/comments', async (req: Request, res: Response) => {
  const comments = await parser.getComments(req.params.id);
  res.json(comments);
});

router.get('/search', async (req: Request, res: Response) => {
  const query = req.query.q as string;
  const page = parseInt(req.query.page as string) || 1;
  
  if (!query) {
    return res.status(400).json({ error: 'Search query required' });
  }

  const results = await parser.searchSubmissions(query, page);
  res.json(results);
});

router.get('/notifications', async (req: Request, res: Response) => {
  const username = req.query.username as string;
  if (!username) {
    return res.status(400).json({ error: 'Username required' });
  }

  const notifications = await parser.getNotifications(username);
  res.json(notifications);
});

router.post('/cache/clear', (req: Request, res: Response) => {
  cache.flushAll();
  res.json({ success: true });
});

export default router;
