const BASE_URL = 'https://www.furaffinity.net';

export const FAUrls = {
  home: BASE_URL,
  login: `${BASE_URL}/login`,
  register: `${BASE_URL}/register`,
  submissions: `${BASE_URL}/msg/submissions/new@72`,
  submissionsFrom: (sid: number) => `${BASE_URL}/msg/submissions/new~${sid}@72`,
  browse: (filter?: string, page?: number) => {
    const f = filter && filter !== 'all' ? `?type=${filterMap[filter as keyof typeof filterMap] || ''}` : '';
    const p = page && page > 1 ? `&page=${page}` : '';
    return `${BASE_URL}/browse/all/${f}${p}`;
  },
  viewSubmission: (id: string) => `${BASE_URL}/view/${id}/`,
  search: (query: string, page?: number) =>
    `${BASE_URL}/search/?q=${encodeURIComponent(query)}${page && page > 1 ? `&page=${page}` : ''}`,
  notifications: `${BASE_URL}/msg/others/`,
  user: (username: string) => `${BASE_URL}/user/${username}/`,
  avatar: (username: string) => `https://a.furaffinity.net/${username}.gif`,
  gallery: (username: string) => `${BASE_URL}/gallery/${username}/`,
  favorites: (username: string) => `${BASE_URL}/favorites/${username}/`,
  journals: (username: string) => `${BASE_URL}/journals/${username}/`,
  journal: (id: string) => `${BASE_URL}/journal/${id}/`,
  watchlist: (username: string, direction: 'to' | 'by', page?: number) =>
    `${BASE_URL}/watchlist/${direction}/${username}/${page && page > 1 ? `?page=${page}` : ''}`,
  notesInbox: `${BASE_URL}/controls/switchbox/inbox/`,
  notesSent: `${BASE_URL}/controls/switchbox/sent/`,
  newNote: (username: string) => `${BASE_URL}/newpm/${username}/`,
};

const filterMap = {
  all: '',
  digital: '1',
  traditional: '2',
  writing: '3',
};
