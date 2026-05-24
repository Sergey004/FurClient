import * as cheerio from 'cheerio';
import {Submission, Comment, FANotification, FAUser} from '../types';

export function parseSubmissionsPage(html: string): Submission[] {
  const $ = cheerio.load(html);
  const submissions: Submission[] = [];

  $('div[id^="sid-"]').each((_, element) => {
    const $el = $(element);
    const id = $el.attr('id')?.replace('sid-', '') || '';
    const $link = $el.find('a[href*="/view/"]').first();
    const title = $link.attr('title') || $link.text() || 'Untitled';
    const url = $link.attr('href') || '';

    const author = $el.find('a[href*="/user/"]').first().text() || 'Unknown';

    const $img = $el.find('img[alt]').first();
    const imageUrl = $img.attr('src') || '';

    const statsText = $el.find('.stats-container, .grid-info').text();
    const viewsMatch = statsText.match(/(\d+)\s+views?/i);
    const favesMatch = statsText.match(/(\d+)\s*[♥]/);

    const tagsText = $el.find('.tags').text();
    const tags = tagsText.split(',').map(t => t.trim().toLowerCase()).filter(t => t);

    const isNsfw = $el.find('[data-rating="adult"], [data-rating="mature"]').length > 0;

    if (id && title) {
      submissions.push({
        id,
        title,
        author,
        category: 'Digital',
        imageUrl,
        views: parseInt(viewsMatch?.[1] || '0'),
        faves: parseInt(favesMatch?.[1] || '0'),
        commentsCount: 0,
        description: '',
        tags,
        date: new Date().toISOString(),
        isNsfw,
        url: `https://www.furaffinity.net${url}`,
      });
    }
  });

  return submissions;
}

export function parseSubmissionDetails(html: string, submissionId: string): Submission | null {
  const $ = cheerio.load(html);

  const title = $('div.information h2').text() || 'Untitled';
  const author = $('a[href*="/user/"]').first().text() || 'Unknown';
  const description = $('div[class*="description"]').text() || '';
  const imageUrl = $('img[alt="Submission"]').attr('src') || $('img#submissionImg').attr('src') || '';

  const views = parseInt($('dt:contains("Views")').next().text() || '0');
  const faves = parseInt($('dt:contains("Favorites")').next().text() || '0');
  const commentsCount = parseInt($('dt:contains("Comments")').next().text() || '0');

  const tagsText = $('section.tags').text();
  const tags = tagsText.split(',').map(t => t.trim().toLowerCase()).filter(t => t);

  const isNsfw = $('[data-rating="adult"], [data-rating="mature"]').length > 0;
  const date = $('dt:contains("Posted")').next().text() || new Date().toISOString();

  return {
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
    url: `https://www.furaffinity.net/view/${submissionId}/`,
  };
}

export function parseComments(html: string): Comment[] {
  const $ = cheerio.load(html);
  const comments: Comment[] = [];

  $('div[id^="cid-"]').each((_, element) => {
    const $el = $(element);
    const id = $el.attr('id')?.replace('cid-', '') || '';
    const author = $el.find('a[href*="/user/"]').first().text() || 'Anonymous';
    const avatarUrl = $el.find('img').first().attr('src') || '';
    const text = $el.find('div.comment-content').text() || '';
    const time = $el.find('span.popup_date').attr('title') || 'Unknown';

    comments.push({id, author, avatarUrl, text, time});
  });

  return comments;
}

export function parseNotifications(html: string): FANotification[] {
  const $ = cheerio.load(html);
  const notifications: FANotification[] = [];

  $('div[id^="notif-"]').each((_, element) => {
    const $el = $(element);
    const id = $el.attr('id') || '';
    const author = $el.find('a[href*="/user/"]').first().text() || 'Unknown';
    const avatarUrl = $el.find('img').first().attr('src') || '';
    const titleText = $el.text() || '';
    const datetime = $el.find('.popup_date').attr('title') || new Date().toISOString();
    const url = $el.find('a').first().attr('href') || '';

    notifications.push({
      id,
      author,
      avatarUrl,
      title: titleText,
      type: 'fave',
      datetime,
      url: `https://www.furaffinity.net${url}`,
    });
  });

  return notifications;
}

export function parseUserPage(html: string, username: string): FAUser | null {
  const $ = cheerio.load(html);

  const displayName = $(`a[href*="/user/${username}/"]`).first().text() || username;
  const avatarUrl = $('img[alt="Avatar"]').attr('src') || '';
  const bannerUrl = $('div[class*="banner"] img').attr('src') || '';
  const description = $('div[class*="description"]').text() || '';

  const views = parseInt($('dt:contains("Views")').next().text() || '0');
  const submissions = parseInt($('dt:contains("Submissions")').next().text() || '0');
  const favorites = parseInt($('dt:contains("Favorites")').next().text() || '0');
  const comments = parseInt($('dt:contains("Comments")').next().text() || '0');
  const journals = parseInt($('dt:contains("Journals")').next().text() || '0');

  const watchButton = $('a[href*="/watch/"], a[href*="/unwatch/"]').first();
  const watchUrl = watchButton.attr('href') || '';
  const isWatching = watchUrl.includes('/unwatch/');

  return {
    username,
    displayName,
    avatarUrl,
    bannerUrl,
    description,
    stats: {views, submissions, favorites, comments, journals},
    isWatching,
    watchUrl: watchUrl ? `https://www.furaffinity.net${watchUrl}` : '',
  };
}

export function parseSearchResults(html: string): Submission[] {
  return parseSubmissionsPage(html);
}
