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

export interface FAUser {
  username: string;
  displayName: string;
  avatarUrl: string;
  bannerUrl: string;
  description: string;
  stats: {
    views: number;
    submissions: number;
    favorites: number;
    comments: number;
    journals: number;
  };
  isWatching: boolean;
  watchUrl: string;
}
