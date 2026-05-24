import { useState, useCallback, useEffect } from 'react';

const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:3001/api';

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

// Hook для загрузки подачи
export function useSubmissions(page: number = 1, filter: string = 'all') {
  const [submissions, setSubmissions] = useState<Submission[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setLoading(true);
    setError(null);

    fetch(`${API_URL}/submissions?page=${page}&filter=${filter}`)
      .then(res => {
        if (!res.ok) throw new Error('Failed to fetch submissions');
        return res.json();
      })
      .then(data => {
        setSubmissions(data);
        setLoading(false);
      })
      .catch(err => {
        setError(err.message);
        setLoading(false);
      });
  }, [page, filter]);

  return { submissions, loading, error };
}

// Hook для загрузки деталей подачи
export function useSubmissionDetails(submissionId: string | null) {
  const [submission, setSubmission] = useState<Submission | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!submissionId) return;

    setLoading(true);
    setError(null);

    fetch(`${API_URL}/submissions/${submissionId}`)
      .then(res => {
        if (!res.ok) throw new Error('Failed to fetch submission');
        return res.json();
      })
      .then(data => {
        setSubmission(data);
        setLoading(false);
      })
      .catch(err => {
        setError(err.message);
        setLoading(false);
      });
  }, [submissionId]);

  return { submission, loading, error };
}

// Hook для загрузки комментариев
export function useComments(submissionId: string | null) {
  const [comments, setComments] = useState<Comment[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!submissionId) return;

    setLoading(true);
    setError(null);

    fetch(`${API_URL}/submissions/${submissionId}/comments`)
      .then(res => {
        if (!res.ok) throw new Error('Failed to fetch comments');
        return res.json();
      })
      .then(data => {
        setComments(data);
        setLoading(false);
      })
      .catch(err => {
        setError(err.message);
        setLoading(false);
      });
  }, [submissionId]);

  return { comments, loading, error };
}

// Hook для поиска
export function useSearch(query: string, page: number = 1) {
  const [results, setResults] = useState<Submission[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!query.trim()) {
      setResults([]);
      return;
    }

    setLoading(true);
    setError(null);

    fetch(`${API_URL}/search?q=${encodeURIComponent(query)}&page=${page}`)
      .then(res => {
        if (!res.ok) throw new Error('Search failed');
        return res.json();
      })
      .then(data => {
        setResults(data);
        setLoading(false);
      })
      .catch(err => {
        setError(err.message);
        setLoading(false);
      });
  }, [query, page]);

  return { results, loading, error };
}

// Hook для уведомлений
export function useNotifications(username: string | null) {
  const [notifications, setNotifications] = useState<FANotification[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!username) return;

    setLoading(true);
    setError(null);

    fetch(`${API_URL}/notifications?username=${encodeURIComponent(username)}`)
      .then(res => {
        if (!res.ok) throw new Error('Failed to fetch notifications');
        return res.json();
      })
      .then(data => {
        setNotifications(data);
        setLoading(false);
      })
      .catch(err => {
        setError(err.message);
        setLoading(false);
      });
  }, [username]);

  const refresh = useCallback(() => {
    if (!username) return;
    
    setLoading(true);
    fetch(`${API_URL}/notifications?username=${encodeURIComponent(username)}`)
      .then(res => res.json())
      .then(data => {
        setNotifications(data);
        setLoading(false);
      })
      .catch(err => {
        setError(err.message);
        setLoading(false);
      });
  }, [username]);

  return { notifications, loading, error, refresh };
}

// Hook для аутентификации
export function useAuth() {
  const [session, setSession] = useState<UserSession | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Загрузить сохраненную сессию при монтировании
  useEffect(() => {
    const savedSession = localStorage.getItem('fa_session');
    if (savedSession) {
      try {
        setSession(JSON.parse(savedSession));
      } catch {
        localStorage.removeItem('fa_session');
      }
    }
  }, []);

  const login = useCallback(async (username: string, password: string) => {
    setLoading(true);
    setError(null);

    try {
      const response = await fetch(`${API_URL}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password }),
        credentials: 'include'
      });

      if (!response.ok) {
        throw new Error('Login failed');
      }

      const data = await response.json() as UserSession;
      setSession(data);
      localStorage.setItem('fa_session', JSON.stringify(data));
      setLoading(false);
      return data;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Login failed';
      setError(message);
      setLoading(false);
      return null;
    }
  }, []);

  const logout = useCallback(() => {
    setSession(null);
    localStorage.removeItem('fa_session');
    setError(null);
  }, []);

  return { session, login, logout, loading, error };
}
