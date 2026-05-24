import { useState, useMemo, FormEvent } from 'react';
import { 
  Monitor, 
  Smartphone, 
  HelpCircle, 
  Upload, 
  Search, 
  Heart, 
  Star, 
  Send, 
  X, 
  Code,
  Check,
  Smartphone as PhoneIcon,
  Cpu,
  Bookmark,
  MessageSquare,
  Sparkles,
  Layers,
  ExternalLink,
  ChevronRight,
  RefreshCw,
  Clock,
  Share2,
  Download,
  Bell,
  Mail,
  Settings,
  Trash2
} from 'lucide-react';

// iOS-inspired Notification Preview Model (from iOS native FAKit project)
interface FANotificationPreview {
  id: number;
  author: string;
  avatar: string;
  title: string;
  type: 'fave' | 'comment' | 'watch' | 'journal';
  datetime: string;
  naturalDatetime: string;
  url: string;
}

// iOS-inspired Direct Message / Note Model (from iOS native FAKit project)
interface FAMessage {
  sender: 'user' | 'other';
  text: string;
  time: string;
}

interface FAConversation {
  id: number;
  author: string;
  displayAuthor: string;
  avatar: string;
  title: string;
  datetime: string;
  naturalDatetime: string;
  unread: boolean;
  messages: FAMessage[];
}

// Structuring mock types for our interactive showcase
interface Comment {
  id: string;
  author: string;
  avatar: string;
  text: string;
  time: string;
}

interface Submission {
  id: string;
  title: string;
  author: string;
  category: 'Digital' | 'Writing' | 'Traditional';
  imageGradient: string;
  views: number;
  faves: number;
  commentsCount: number;
  description: string;
  tags: string[];
  comments: Comment[];
  date: string;
  isNsfw?: boolean;
}

const INITIAL_SUBMISSIONS: Submission[] = [
  {
    id: 'sub-1',
    title: 'Midnight Forest Run',
    author: 'AeroWolf',
    category: 'Digital',
    imageGradient: 'from-blue-900/60 via-indigo-900/40 to-slate-900',
    views: 1240,
    faves: 342,
    commentsCount: 14,
    description: 'A personal piece exploring dynamic lighting and mist inside the old growth forest. Trying to push faster painting times and more atmospheric shadows.',
    tags: ['wolf', 'anthro', 'forest', 'nature', 'midnight', 'running', 'canine', 'atmospheric'],
    date: '2026-05-23 12:44',
    comments: [
      { id: 'c-1', author: 'SilverVulpine', avatar: 'from-orange-400 to-purple-600', text: 'This lighting has such an incredible depth! The blue mist is gorgeous.', time: '2 hours ago' },
      { id: 'c-2', author: 'NeonCoyote', avatar: 'from-pink-500 to-cyan-500', text: 'Stunning speedpaint Aero! Do you plan on printing this?', time: '1 hour ago' }
    ]
  },
  {
    id: 'sub-2',
    title: 'Cybernetic Dreams (18+)',
    author: 'NeonCoyote',
    category: 'Digital',
    imageGradient: 'from-orange-950/60 via-purple-950/40 to-slate-900',
    views: 890,
    faves: 212,
    commentsCount: 8,
    description: 'Futuristic streets reflecting high-luminosity cybernetic implants. Dedicated to the classic retro-wave aesthetic with a modern twist of tech-neon (SFW/NSFW toggled illustration).',
    tags: ['coyote', 'cyberpunk', 'neon', 'artificial', 'retro', 'glowing', 'urban', 'pinup'],
    date: '2026-05-23 10:15',
    isNsfw: true,
    comments: [
      { id: 'c-3', author: 'LunaArtist', avatar: 'from-purple-400 to-indigo-600', text: 'That glow is crazy detailed, love the contrast with the deep dark alleys!', time: '3 hours ago' }
    ]
  },
  {
    id: 'sub-3',
    title: 'Study of Light #24',
    author: 'LunaArtist',
    category: 'Digital',
    imageGradient: 'from-purple-900/60 via-pink-950/40 to-slate-900',
    views: 745,
    faves: 184,
    commentsCount: 5,
    description: 'Experimenting with dramatic golden hour highlights reflecting off wet scales. Spent about 4 hours on this particular anatomy angle.',
    tags: ['feline', 'fantasy', 'anatomy', 'study', 'chasing-sunlight', 'golden-hour'],
    date: '2026-05-22 18:30',
    comments: []
  },
  {
    id: 'sub-4',
    title: 'Commission: Drax',
    author: 'ScalieMaster',
    category: 'Digital',
    imageGradient: 'from-emerald-900/60 via-teal-950/40 to-slate-900',
    views: 1980,
    faves: 541,
    commentsCount: 22,
    description: 'Commission for a majestic dragon looking out from an obsidian fortress over standard magma scenery. Absolutely loved working on the texture of the horns.',
    tags: ['dragon', 'scalie', 'commission', 'magma', 'horns', 'illustration'],
    date: '2026-05-22 14:12',
    comments: [
      { id: 'c-4', author: 'LunaArtist', avatar: 'from-purple-400 to-indigo-600', text: 'Drax looks so imposing here! Phenomenal scale render.', time: '1 day ago' }
    ]
  },
  {
    id: 'sub-5',
    title: 'Crimson Peak',
    author: 'VibeCheck',
    category: 'Traditional',
    imageGradient: 'from-red-900/60 via-rose-950/40 to-slate-900',
    views: 520,
    faves: 99,
    commentsCount: 4,
    description: 'Acrylic sketch on heavy grain cotton paper. Visualizes tension at high-altitude mountain lookouts under scarlet red dust storms.',
    tags: ['traditional', 'acrylic', 'mountain', 'crimson', 'dust-storm', 'vulture'],
    date: '2026-05-21 09:30',
    comments: []
  },
  {
    id: 'sub-6',
    title: 'Character Sheet v2',
    author: 'FoxTailDesign',
    category: 'Digital',
    imageGradient: 'from-pink-900/60 via-slate-800 to-slate-900',
    views: 1100,
    faves: 280,
    commentsCount: 19,
    description: 'Updated reference detailing outfit presets, seasonal color variants, expression keys and inventory highlights for the main character.',
    tags: ['fox', 'ref-sheet', 'character-design', 'wardrobe', 'flat-colors', 'cute'],
    date: '2026-05-20 22:45',
    comments: []
  },
  {
    id: 'sub-7',
    title: 'Ocean Breezes',
    author: 'SharkyBoy',
    category: 'Digital',
    imageGradient: 'from-cyan-900/60 via-blue-950/40 to-slate-900',
    views: 610,
    faves: 104,
    commentsCount: 3,
    description: 'Sleek aquatic environment design during dynamic afternoon tides. Focus on clear water rendering and subsurface scattering of sunlight.',
    tags: ['shark', 'swimmer', 'underwater', 'ocean', 'tides', 'breeze'],
    date: '2026-05-20 15:55',
    comments: []
  },
  {
    id: 'sub-8',
    title: 'Sketch Dump May',
    author: 'PencilPusher',
    category: 'Writing',
    imageGradient: 'from-gray-700/60 via-slate-800 to-slate-900',
    views: 430,
    faves: 56,
    commentsCount: 1,
    description: 'Various raw sketches, prose attempts, and short character stories compiled from my leather notebooks. Contains brief narrative scripts.',
    tags: ['sketches', 'writing', 'compilation', 'short-stories', 'notebooks', 'hybrid'],
    date: '2026-05-19 11:20',
    comments: []
  }
];

export default function App() {
  // Navigation & Interactive Tabs
  const [activeTab, setActiveTab] = useState<'home' | 'notifications' | 'notes' | 'compare' | 'blueprints' | 'settings'>('home');
  const [selectedSub, setSelectedSub] = useState<Submission | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<'All' | 'Digital' | 'Traditional' | 'Writing'>('All');
  
  // Custom interactive mock database states
  const [submissions, setSubmissions] = useState<Submission[]>(INITIAL_SUBMISSIONS);
  const [commentText, setCommentText] = useState('');
  
  // Multiplatform view emulator state
  // This physically lets the client experience the app in Windows 11 Desktop (WinUI 3 Layout) or Android Phone (Material You bottom-bar layout).
  const [simulatedPlatform, setSimulatedPlatform] = useState<'windows' | 'android'>('windows');

  // iOS App Preferences / Simulation parameters ported directly from the iOS Preferences code!
  const [sfwMode, setSfwMode] = useState<boolean>(true);
  const [imgQuality, setImgQuality] = useState<'low' | 'med' | 'hd'>('hd');
  const [soundEnabled, setSoundEnabled] = useState<boolean>(true);
  const [autoDownloadOnLike, setAutoDownloadOnLike] = useState<boolean>(true);

  // New mock notifications state based on FANotificationPreview model
  const [notifications, setNotifications] = useState<FANotificationPreview[]>([
    { id: 101, author: 'SilverVulpine', avatar: 'from-orange-400 to-purple-600', title: 'добавил "Midnight Forest Run" в Избранное', type: 'fave', datetime: '2026-05-24 11:30', naturalDatetime: '10 минут назад', url: 'https://www.furaffinity.net/view/sub-1/' },
    { id: 102, author: 'Koda', avatar: 'from-teal-400 to-emerald-600', title: 'оставил комментарий под вашим артом "Study of Light #24"', type: 'comment', datetime: '2026-05-24 11:15', naturalDatetime: '25 минут назад', url: 'https://www.furaffinity.net/view/sub-3/' },
    { id: 103, author: 'Ceylo', avatar: 'from-blue-500 to-cyan-500', title: 'начал следить за вашим творчеством (+Watch)', type: 'watch', datetime: '2026-05-24 10:45', naturalDatetime: '1 час назад', url: 'https://www.furaffinity.net/user/ceylo/' },
    { id: 104, author: 'DracoArts', avatar: 'from-purple-500 to-pink-500', title: 'опубликовал новый Журнал: "Открытые комиссии!"', type: 'journal', datetime: '2026-05-24 09:20', naturalDatetime: '2 часа назад', url: 'https://www.furaffinity.net/journal/1204/' },
    { id: 105, author: 'NeonCoyote', avatar: 'from-pink-500 to-cyan-500', title: 'добавил "Crimson Peak" в Избранное', type: 'fave', datetime: '2026-05-23 23:10', naturalDatetime: 'Вчера', url: 'https://www.furaffinity.net/view/sub-5/' }
  ]);

  // Selected state for individual notifications checkbox removal
  const [selectedNotifIds, setSelectedNotifIds] = useState<number[]>([]);

  // New mock direct messages state based on FANotePreview / FANote Models
  const [conversations, setConversations] = useState<FAConversation[]>([
    {
      id: 401,
      author: 'AeroWolf',
      displayAuthor: 'AeroWolf',
      avatar: 'from-blue-600 to-indigo-800',
      title: 'Насчет заказа на комиссии',
      datetime: '2026-05-24 12:00',
      naturalDatetime: '30 минут назад',
      unread: true,
      messages: [
        { sender: 'other', text: 'Привет! Я увидел твои наброски в Sketch Dump. Очень качественные переходы светотени! Ты сейчас принимаешь заказы?', time: 'Вчера 18:20' },
        { sender: 'user', text: 'Привет! Спасибо большое, очень приятно слышать от тебя. Да, места еще есть, планирую открыть 3 слота на следующей неделе.', time: 'Вчера 19:10' },
        { sender: 'other', text: 'Отлично! Запиши меня на один полноразмерный арт с фоном в стиле Midnight Forest. Готов внести предоплату сразу.', time: '30 минут назад' }
      ]
    },
    {
      id: 402,
      author: 'LunaArtist',
      displayAuthor: 'Luna (Commissions Open)',
      avatar: 'from-purple-400 to-indigo-600',
      title: 'Фидбек по коллабу',
      datetime: '2026-05-23 15:45',
      naturalDatetime: '1 день назад',
      unread: false,
      messages: [
        { sender: 'other', text: 'Хей, закончила свою часть лайн-арта для нашего коллаба. Скинула PSD файл на почту.', time: '2 дня назад' },
        { sender: 'user', text: 'Ого, так быстро! Выглядит потрясающе, уже приступаю к покрасу тени.', time: '1 день назад' },
        { sender: 'other', text: 'Супер, жду не дождусь финального результата! ❤️', time: '1 день назад' }
      ]
    },
    {
      id: 403,
      author: 'NeonCoyote',
      displayAuthor: 'NeonCoyote',
      avatar: 'from-pink-500 to-cyan-500',
      title: 'Сейв-поинт референса',
      datetime: '2026-05-22 08:30',
      naturalDatetime: '2 дня назад',
      unread: false,
      messages: [
        { sender: 'other', text: 'Привет, можешь скинуть векторный исходник персонажа со второго листа?', time: '2 дня назад' },
        { sender: 'user', text: 'Лови ссылку на гуглдрайв! Напиши, если возникнут проблемы с импортом слоев.', time: '2 дня назад' }
      ]
    }
  ]);

  const [selectedConvId, setSelectedConvId] = useState<number>(401);
  const [newReplyText, setNewReplyText] = useState('');

  // SFW filter overlay simulation info toast
  const [sfwToast, setSfwToast] = useState<string | null>(null);

  // New mock upload state
  const [isUploadOpen, setIsUploadOpen] = useState(false);
  const [newTitle, setNewTitle] = useState('');
  const [newArtist, setNewArtist] = useState('');
  const [newCategory, setNewCategory] = useState<'Digital' | 'Writing' | 'Traditional'>('Digital');
  const [newGradient, setNewGradient] = useState('from-indigo-900/60 via-purple-900/40 to-slate-900');
  const [newDescription, setNewDescription] = useState('');
  const [newTagsStr, setNewTagsStr] = useState('');

  // Selected Flutter Integration parameters for state simulation
  const [flutterSelectedTarget, setFlutterSelectedTarget] = useState<'winui3' | 'android'>('winui3');

  // Code Blueprints selector state matching the uploaded FurAffinityApp-main.zip source files!
  const [blueprintFile, setBlueprintFile] = useState<'login' | 'submission_page' | 'online_session'>('submission_page');
  const [blueprintLanguage, setBlueprintLanguage] = useState<'swift' | 'dart'>('dart');

  // Share and Download temporary feedback toasts
  const [shareToast, setShareToast] = useState<string | null>(null);
  const [downloadToast, setDownloadToast] = useState<string | null>(null);
  const [downloadingPercent, setDownloadingPercent] = useState<number | null>(null);

  // Background concurrent downloads queue representation
  interface ActiveDownload {
    id: string;
    title: string;
    percent: number;
    triggerType: 'like' | 'manual';
  }
  const [activeDownloads, setActiveDownloads] = useState<ActiveDownload[]>([]);

  const startBackgroundDownload = (sub: Submission, triggerType: 'like' | 'manual') => {
    const downloadId = `${sub.id}-${triggerType}-${Date.now()}`;
    
    setActiveDownloads(prev => [...prev, {
      id: downloadId,
      title: sub.title,
      percent: 0,
      triggerType
    }]);

    if (triggerType === 'manual') {
      setDownloadingPercent(0);
    }

    let progress = 0;
    const interval = setInterval(() => {
      progress += 10;
      
      setActiveDownloads(prev => prev.map(dl => {
        if (dl.id === downloadId) {
          return { ...dl, percent: progress };
        }
        return dl;
      }));

      if (triggerType === 'manual') {
        setDownloadingPercent(progress >= 100 ? null : progress);
      }

      if (progress >= 100) {
        clearInterval(interval);
        
        setTimeout(() => {
          setActiveDownloads(prev => prev.filter(dl => dl.id !== downloadId));
        }, 1500);

        const label = triggerType === 'like' ? 'лайка ❤️ (авто)' : 'запроса HD 💾';
        setDownloadToast(`Файл [FA_${sub.title.replace(/\s+/g, '_')}.png] успешно скачан в фоне после ${label}!`);
        setTimeout(() => setDownloadToast(null), 4000);
      }
    }, 120);
  };

  const handleShare = (sub: Submission) => {
    const url = `https://www.furaffinity.net/view/${sub.id}/`;
    navigator.clipboard.writeText(url).then(() => {
      setShareToast(`Ссылка на "${sub.title}" скопирована в буфер обмена!`);
      setTimeout(() => setShareToast(null), 3500);
    }).catch(() => {
      setShareToast(`furaffinity.net/view/${sub.id}/`);
      setTimeout(() => setShareToast(null), 5000);
    });
  };

  const handleDownload = (sub: Submission) => {
    // Check if copy is already downloading to avoid duplicate downloads
    const isDownloading = activeDownloads.some(dl => dl.title === sub.title && dl.triggerType === 'manual');
    if (isDownloading) return;
    startBackgroundDownload(sub, 'manual');
  };

  // Filter and search logic
  const filteredSubmissions = useMemo(() => {
    return submissions.filter(sub => {
      const matchesSearch = sub.title.toLowerCase().includes(searchQuery.toLowerCase()) || 
                            sub.author.toLowerCase().includes(searchQuery.toLowerCase()) ||
                            sub.tags.some(t => t.toLowerCase().includes(searchQuery.toLowerCase()));
      const matchesCat = selectedCategory === 'All' ? true : sub.category === selectedCategory;
      return matchesSearch && matchesCat;
    });
  }, [submissions, searchQuery, selectedCategory]);

  // Handle local comment submission
  const handleAddComment = (e: FormEvent) => {
    e.preventDefault();
    if (!commentText.trim() || !selectedSub) return;

    const newComment: Comment = {
      id: `comment-${Date.now()}`,
      author: 'SilverVulpine',
      avatar: 'from-orange-400 to-purple-600',
      text: commentText.trim(),
      time: 'Just now'
    };

    const updatedSubmissions = submissions.map(sub => {
      if (sub.id === selectedSub.id) {
        return {
          ...sub,
          commentsCount: sub.commentsCount + 1,
          comments: [...sub.comments, newComment]
        };
      }
      return sub;
    });

    setSubmissions(updatedSubmissions);
    // Move up updated selection state
    setSelectedSub(prev => prev ? {
      ...prev,
      commentsCount: prev.commentsCount + 1,
      comments: [...prev.comments, newComment]
    } : null);
    
    setCommentText('');
  };

  // Toggle favorite on current open submission
  const handleToggleFave = (id: string) => {
    const targetSub = submissions.find(sub => sub.id === id);
    if (targetSub && autoDownloadOnLike) {
      // Automatic background download on Like!
      startBackgroundDownload(targetSub, 'like');
    }

    setSubmissions(prev => prev.map(sub => {
      if (sub.id === id) {
        return { ...sub, faves: sub.faves + 1 };
      }
      return sub;
    }));
    // Also update modal selection
    setSelectedSub(prev => prev && prev.id === id ? { ...prev, faves: prev.faves + 1 } : prev);
  };

  // Preset gradients available for uploads
  const gradientPresets = [
    { value: 'from-orange-900/65 via-yellow-950/45 to-slate-900', label: 'Sunlight Flare' },
    { value: 'from-amber-900/60 via-red-950/40 to-slate-900', label: 'Autumn Canopy' },
    { value: 'from-violet-900/60 via-pink-950/45 to-slate-900', label: 'Neon Cyberpunk' },
    { value: 'from-emerald-900/60 via-teal-950/40 to-slate-900', label: 'Deep Moss' },
    { value: 'from-slate-700/60 via-indigo-950/40 to-slate-900', label: 'Stormy Night' }
  ];

  // Handle creation of mock submissions
  const handleCreateUpload = (e: FormEvent) => {
    e.preventDefault();
    if (!newTitle.trim() || !newArtist.trim()) return;

    const parsedTags = newTagsStr
      .split(',')
      .map(tag => tag.trim().toLowerCase())
      .filter(tag => tag.length > 0);

    const newSub: Submission = {
      id: `sub-custom-${Date.now()}`,
      title: newTitle,
      author: newArtist.startsWith('@') ? newArtist.slice(1) : newArtist,
      category: newCategory,
      imageGradient: newGradient,
      views: 120,
      faves: 10,
      commentsCount: 0,
      description: newDescription || 'An open-source custom submission created in the FA Nexus Interactive Playground.',
      tags: parsedTags.length > 0 ? parsedTags : ['custom', 'user-upload', 'nexus-interactive'],
      date: new Date().toISOString().replace('T', ' ').substring(0, 16),
      comments: []
    };

    setSubmissions([newSub, ...submissions]);
    setIsUploadOpen(false);

    // Reset fields
    setNewTitle('');
    setNewArtist('');
    setNewDescription('');
    setNewTagsStr('');
  };

  // Flutter Scraper Config settings
  const flutterConfigs = {
    packageName: 'fa_nexus_client',
    dependencies: ['fluent_ui', 'html', 'http', 'cookie_jar', 'webview_flutter'],
    scraperTarget: 'https://www.furaffinity.net',
  };

  return (
    <div className="min-h-screen bg-[#090909] text-gray-200 antialiased font-sans p-4 md:p-8 flex flex-col items-center justify-start gap-6">
      
      {/* Upper Information Banner explaining the chosen Flutter solution */}
      <div className="w-full max-w-6xl mx-auto bg-gradient-to-r from-cyan-950/40 via-blue-950/40 to-slate-900/40 border border-[#60cdff]/20 rounded-xl p-5 shadow-2xl backdrop-blur-md flex flex-col lg:flex-row gap-6 items-start justify-between">
        <div className="flex-1 space-y-2">
          <div className="flex flex-wrap items-center gap-3">
            <span className="bg-[#0078d4]/30 text-[#60cdff] text-xs font-semibold px-2.5 py-1 rounded-md border border-[#60cdff]/30 uppercase tracking-wide">
              Selected Target Tech Stack
            </span>
            <span className="text-gray-400 text-xs">Targeting: Flutter (WinUI 3, Android, iOS)</span>
          </div>
          <h2 className="text-xl md:text-2xl font-bold tracking-tight text-white flex items-center gap-2">
            <span className="text-[#60cdff]">FA Nexus Client Blueprint:</span> Flutter Ecosystem Chosen
          </h2>
          <p className="text-sm text-gray-300 leading-relaxed max-w-4xl">
            Пользовательское приложение <strong>NOC for Fur Affinity</strong> сейчас испытывает проблемы. В качестве замены мы выбрали <strong>Flutter (Dart)</strong> 
            из-за легкой кроссплатформенности и непревзойденной нативной производительности на <strong>Windows (WinUI 3)</strong>. 
            Ниже вы найдете <strong>интерактивный симулятор интерфейса клиента</strong>, детальный технический анализ архитектуры и готовые шаблоны исходного кода.
          </p>
        </div>
        
        {/* Rapid Choice Card (Flutter Oriented) */}
        <div className="w-full lg:w-auto bg-[#1a1a1a]/85 border border-white/5 p-4 rounded-lg flex flex-col gap-3 shrink-0 min-w-[280px]">
          <span className="text-xs text-gray-400 uppercase tracking-widest font-semibold block">Выбор технологии: Flutter</span>
          <div className="flex items-start gap-2 text-xs">
            <span className="text-emerald-400 mt-0.5">✓</span>
            <p className="text-gray-300">
              Высокая производительность <strong>60-120 FPS</strong> при рендеринге бесконечных лент с артами.
            </p>
          </div>
          <div className="flex items-start gap-2 text-xs">
            <span className="text-emerald-400 mt-0.5">✓</span>
            <p className="text-gray-300">
              Полноценная интеграция с дизайном <strong>WinUI 3</strong> на Windows через пакет <code>fluent_ui</code>.
            </p>
          </div>
          <button 
            onClick={() => setActiveTab('blueprints')} 
            className="w-full text-center py-1.5 px-3 rounded text-xs font-semibold bg-[#0078d4] text-white hover:bg-[#0078d4]/80 transition flex items-center justify-center gap-1.5"
          >
            Исходный Код (Flutter) <ChevronRight className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>

      {/* Main Showcase Workspace Area */}
      <div className="w-full max-w-6xl mx-auto grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        
        {/* Navigation Sidebar Area (WinUI 3 styled, Mica simulation) */}
        <div className="lg:col-span-3 bg-[#111111]/90 rounded-xl border border-white/5 p-4 shadow-xl space-y-6 flex flex-col">
          
          <div className="flex items-center gap-2.5 px-2">
            <div className="w-8 h-8 rounded-lg bg-[#0078d4] flex items-center justify-center text-xs font-bold text-white shadow-md">
              FA
            </div>
            <div>
              <div className="font-semibold text-white text-sm">FA Nexus Open</div>
              <div className="text-[10px] text-[#60cdff]">Open-Source Client</div>
            </div>
          </div>

          {/* Simulated Workspace Controls */}
          <div className="space-y-1">
            <div className="text-[10px] px-2 py-1 text-gray-500 uppercase tracking-widest font-bold">Навигация</div>
            
            <button
              onClick={() => { setActiveTab('home'); setSelectedSub(null); }}
              className={`w-full flex items-center justify-between px-3 py-2 rounded-lg text-xs font-medium transition ${
                activeTab === 'home' && !selectedSub
                  ? 'bg-white/5 text-white border-l-2 border-[#60cdff]'
                  : 'text-gray-400 hover:text-white hover:bg-white/5'
              }`}
            >
              <span className="flex items-center gap-2">
                <span>🏠</span> Обзор Галереи
              </span>
              <span className="text-[10px] font-mono text-gray-500">Ctrl+1</span>
            </button>

            <button
              onClick={() => { setActiveTab('notifications'); setSelectedSub(null); }}
              className={`w-full flex items-center justify-between px-3 py-2 rounded-lg text-xs font-medium transition ${
                activeTab === 'notifications'
                  ? 'bg-white/5 text-white border-l-2 border-[#60cdff]'
                  : 'text-gray-400 hover:text-white hover:bg-white/5'
              }`}
            >
              <span className="flex items-center gap-2">
                <span>🔔</span> Уведомления
                {notifications.length > 0 && (
                  <span className="bg-amber-500 text-black font-bold text-[9px] px-1.5 py-0.2 rounded-full scale-90">
                    {notifications.length}
                  </span>
                )}
              </span>
              <span className="text-[10px] font-mono text-gray-500">Ctrl+2</span>
            </button>

            <button
              onClick={() => { setActiveTab('notes'); setSelectedSub(null); }}
              className={`w-full flex items-center justify-between px-3 py-2 rounded-lg text-xs font-medium transition ${
                activeTab === 'notes'
                  ? 'bg-white/5 text-white border-l-2 border-[#60cdff]'
                  : 'text-gray-400 hover:text-white hover:bg-white/5'
              }`}
            >
              <span className="flex items-center gap-2">
                <span>📬</span> Личные Сообщения
                {conversations.some(c => c.unread) && (
                  <span className="bg-[#60cdff] text-black font-bold text-[9px] px-1.5 py-0.2 rounded-full scale-90">
                    {conversations.filter(c => c.unread).length}
                  </span>
                )}
              </span>
              <span className="text-[10px] font-mono text-gray-500">Ctrl+3</span>
            </button>

            <button
              onClick={() => { setActiveTab('blueprints'); setSelectedSub(null); }}
              className={`w-full flex items-center justify-between px-3 py-2 rounded-lg text-xs font-medium transition ${
                activeTab === 'blueprints'
                  ? 'bg-white/5 text-white border-l-2 border-[#60cdff]'
                  : 'text-gray-400 hover:text-white hover:bg-white/5'
              }`}
            >
              <span className="flex items-center gap-2">
                <span>📦</span> Структура Исходников
              </span>
              <span className="text-[10px] font-mono text-gray-500">Ctrl+4</span>
            </button>

            <button
              onClick={() => { setActiveTab('settings'); setSelectedSub(null); }}
              className={`w-full flex items-center justify-between px-3 py-2 rounded-lg text-xs font-medium transition ${
                activeTab === 'settings'
                  ? 'bg-white/5 text-white border-l-2 border-[#60cdff]'
                  : 'text-gray-400 hover:text-white hover:bg-white/5'
              }`}
            >
              <span className="flex items-center gap-2">
                <span>⚙️</span> Настройки Симулятора
              </span>
              <span className="text-[10px] font-mono text-gray-500">Ctrl+6</span>
            </button>
          </div>

          {/* Interactive Shell Switcher (Windows vs Mobile Frame) */}
          <div className="bg-[#181818] rounded-lg p-3 border border-white/5 space-y-2">
            <span className="text-[10px] text-gray-400 uppercase tracking-wider font-semibold block">
              Тест Адаптации UI
            </span>
            <p className="text-[11px] text-gray-300">
              Посмотрите, как приложение трансформируется под разные платформы:
            </p>
            <div className="grid grid-cols-2 gap-1 grid-flow-row">
              <button
                onClick={() => setSimulatedPlatform('windows')}
                className={`py-1.5 px-1 rounded flex flex-col items-center justify-center gap-1 transition ${
                  simulatedPlatform === 'windows'
                    ? 'bg-[#0078d4] text-white font-semibold shadow-inner'
                    : 'bg-white/5 text-gray-400 hover:bg-white/10'
                }`}
                title="Sleek Fluent WinUI 3 Client (Windows 11)"
              >
                <Monitor className="w-4 h-4 text-cyan-400" />
                <span className="text-[9px]">WinUI 3</span>
              </button>
              
              <button
                onClick={() => setSimulatedPlatform('android')}
                className={`py-1.5 px-1 rounded flex flex-col items-center justify-center gap-1 transition ${
                  simulatedPlatform === 'android'
                    ? 'bg-emerald-600/80 text-white font-semibold shadow-inner'
                    : 'bg-white/5 text-gray-400 hover:bg-white/10'
                }`}
                title="Android Material You Layout (Material 3)"
              >
                <Smartphone className="w-4 h-4 text-green-400" />
                <span className="text-[9px]">Material You</span>
              </button>
            </div>
          </div>

          {/* Flutter Core Setup Checklist */}
          <div className="bg-[#141414] rounded-xl p-3 border border-white/5 space-y-2 text-xs">
            <div className="flex items-center gap-1.5 text-xs font-semibold text-emerald-400">
              <span className="w-2 h-2 rounded-full bg-emerald-400 block animate-pulse"></span>
              <span>Flutter Setup Status</span>
            </div>
            
            <p className="text-[11px] text-gray-400 leading-relaxed">
              Компоненты надежного кроссплатформенного клиента на <strong>Flutter (Dart)</strong>:
            </p>

            <div className="space-y-1.5 pt-1 text-[11px] text-gray-300">
              <div className="flex items-center gap-1.5">
                <span className="text-emerald-400">✓</span>
                <span>WinUI 3 Fluent UX Core</span>
              </div>
              <div className="flex items-center gap-1.5">
                <span className="text-emerald-400">✓</span>
                <span>Cookie Auth Session Manager</span>
              </div>
              <div className="flex items-center gap-1.5">
                <span className="text-emerald-400">✓</span>
                <span>HTML Scraper & Parser Engine</span>
              </div>
              <div className="flex items-center gap-1.5">
                <span className="text-emerald-400">✓</span>
                <span>Fast Image Cache on iOS/Android</span>
              </div>
            </div>

            <button
              onClick={() => setActiveTab('blueprints')}
              className="w-full text-center mt-2 py-1 bg-[#1a1a1a] hover:bg-white/5 border border-white/10 text-white rounded text-[11px] font-semibold transition"
            >
              Код Парсера & UI (Flutter)
            </button>
          </div>

          {/* Author/Sync status panel */}
          <div className="mt-auto border-t border-white/5 pt-3">
            <div className="flex items-center gap-3 p-1.5 rounded-lg hover:bg-white/5 cursor-pointer">
              <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-orange-400 via-[#60cdff] to-purple-600 flex items-center justify-center text-[11px] font-bold text-white shadow-inner">
                SV
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-xs font-medium text-white truncate">SilverVulpine</p>
                <p className="text-[9px] text-emerald-400 flex items-center gap-1 font-mono">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 inline-block animate-pulse"></span>
                  Synced • Sandbox
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* Dynamic Display Shell View (Center - Interactive Simulator or Guides) */}
        <div className="lg:col-span-9 space-y-6">
          
          {/* Main conditional rendering depending on chosen tab */}
          {['home', 'notifications', 'notes', 'settings'].includes(activeTab) && (
            <div className="space-y-6">
              
              {/* Device platform outer simulator layout wrapper */}
              <div className="bg-[#121212]/95 rounded-2xl border border-white/5 shadow-2xl overflow-hidden">
                
                {/* Simulated Platform Title Bar / Status headers */}
                <div className="bg-black/60 px-4 py-2 flex items-center justify-between border-b border-white/5 text-xs text-gray-400">
                  <div className="flex items-center gap-2">
                    <span className="w-2.5 h-2.5 rounded-full bg-red-500/80 inline-block"></span>
                    <span className="w-2.5 h-2.5 rounded-full bg-yellow-500/80 inline-block"></span>
                    <span className="w-2.5 h-2.5 rounded-full bg-green-500/80 inline-block"></span>
                    <span className="ml-2 font-semibold text-white tracking-wide">
                      {simulatedPlatform === 'windows' && 'Windows 11 Client • Fluent WinUI 3 (1024px)'}
                      {simulatedPlatform === 'android' && 'Android SFW Client • Material You (Pixel 8)'}
                    </span>
                  </div>
                  <div className="flex items-center gap-3 text-[10px] font-mono">
                    <span className="bg-white/10 text-white px-2 py-0.5 rounded text-[9px] font-sans">
                      {simulatedPlatform.toUpperCase()}
                    </span>
                    <span className="flex items-center gap-1">
                      <Clock className="w-3 h-3 text-cyan-400" /> 17:22 UTC
                    </span>
                  </div>
                </div>

                {/* Simulated Platform Adaptive Render frame */}
                <div className="p-4 md:p-6 bg-gradient-to-b from-[#181818] to-[#121212] min-h-[580px] flex justify-center items-start">
                  
                  {simulatedPlatform === 'windows' ? (
                    /* WINDOWS 11 / WINUI 3 DESKTOP LAYOUT (Elegant translucent design, sidebar, grid) */
                    <div className="w-full bg-[#1e1e1e] border border-white/10 rounded-lg shadow-xl overflow-hidden flex flex-col min-h-[500px]">
                      
                      {/* Windows Ribbon Header */}
                      <header className="h-14 bg-[#1b1b1b] flex items-center justify-between px-6 border-b border-white/5">
                        <div className="flex items-center gap-4 flex-1 max-w-sm">
                          <div className="search-box flex items-center px-3 py-1.5 rounded bg-white/5 border border-white/10 border-b-[#60cdff] w-full gap-2.5">
                            <Search className="w-3.5 h-3.5 text-gray-400 shrink-0" />
                            <input 
                              type="text" 
                              value={searchQuery}
                              onChange={(e) => setSearchQuery(e.target.value)}
                              placeholder="Search Fur Affinity submissions..." 
                              className="bg-transparent border-none outline-none text-xs text-gray-200 placeholder-gray-500 w-full"
                            />
                            {searchQuery && (
                              <button onClick={() => setSearchQuery('')}>
                                <X className="w-3 h-3 text-gray-400" />
                              </button>
                            )}
                          </div>
                        </div>

                        {/* Top action flags */}
                        <div className="flex items-center gap-3.5">
                          <button 
                            onClick={() => setIsUploadOpen(true)}
                            className="bg-[#0078d4] text-white hover:bg-[#0078d4]/80 text-xs px-3.5 py-1.5 rounded font-medium flex items-center gap-1.5 transition shadow"
                          >
                            <Upload className="w-3.5 h-3.5" /> Загрузить
                          </button>
                          <div className="flex items-center gap-2 text-gray-400 text-sm">
                            <span className="hover:text-white cursor-pointer" title="Favorites Count">⭐️</span>
                            <span className="hover:text-white cursor-pointer" title="Notifications">✉️</span>
                          </div>
                        </div>
                      </header>

                      {/* Filter Row */}
                      <div className="bg-[#161616] px-6 py-2 border-b border-white/5 flex items-center justify-between">
                        <div className="flex gap-2">
                          {(['All', 'Digital', 'Traditional', 'Writing'] as const).map(cat => (
                            <button
                              key={cat}
                              onClick={() => setSelectedCategory(cat)}
                              className={`px-3 py-1 rounded text-[11px] font-medium transition ${
                                selectedCategory === cat 
                                  ? 'bg-[#0078d4]/20 text-[#60cdff] border border-[#60cdff]/30' 
                                  : 'hover:bg-white/5 text-gray-400 hover:text-white'
                              }`}
                            >
                              {cat === 'All' ? 'Все медиа' : cat}
                            </button>
                          ))}
                        </div>
                        <div className="text-[10px] text-gray-400">
                          Показано: {filteredSubmissions.length} работа
                        </div>
                      </div>

                      {/* Grid content space */}
                      <div className="p-6 flex-1 max-h-[460px] overflow-y-auto">
                        
                        {activeTab === 'home' && (
                          filteredSubmissions.length === 0 ? (
                            <div className="text-center py-16 space-y-2">
                              <div className="text-3xl">🏜️</div>
                              <h4 className="text-white text-sm font-semibold">Ничего не найдено</h4>
                              <p className="text-xs text-gray-500">Попробуйте изменить запрос поиска или категорию</p>
                            </div>
                          ) : (
                            <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 xl:grid-cols-4 gap-4">
                              {filteredSubmissions.map((sub) => (
                                <div
                                  key={sub.id}
                                  onClick={() => {
                                    if (sub.isNsfw && sfwMode) {
                                      setSfwToast(`Для просмотра "${sub.title}" отключите "SFW-фильтр" во вкладке Настройки! 😉`);
                                      setTimeout(() => setSfwToast(null), 4000);
                                    } else {
                                      setSelectedSub(sub);
                                    }
                                  }}
                                  className="win-card bg-[#282828]/50 hover:bg-[#323232]/80 border border-white/5 hover:border-white/15 p-2.5 rounded-lg flex flex-col gap-2 cursor-pointer transition-all duration-200 group relative shadow-md"
                                >
                                  <div className={`aspect-square w-full rounded-md bg-gradient-to-br ${sub.imageGradient} flex items-center justify-center text-xs text-center p-3 relative overflow-hidden shadow-inner`}>
                                    
                                    {/* Watermark/Furry accent */}
                                    <div className="absolute inset-0 bg-black/10 group-hover:bg-black/20 transition-all rounded" />
                                    
                                    {sub.isNsfw && sfwMode ? (
                                      <div className="absolute inset-0 bg-black/95 backdrop-blur-md flex flex-col items-center justify-center p-2 text-center z-10">
                                        <span className="text-lg">🔞</span>
                                        <span className="text-[10px] text-red-400 font-bold uppercase tracking-wider mt-1">18+ NSFW</span>
                                        <span className="text-[8px] text-gray-400 mt-0.5 max-w-[124px] leading-snug">Скрыто SFW-фильтром</span>
                                      </div>
                                    ) : (
                                      <>
                                        <span className="z-10 text-white/55 text-[10px] font-mono tracking-widest uppercase block border border-white/10 px-2 py-0.5 rounded bg-black/40">
                                          {sub.category}
                                        </span>

                                        {/* Hover eye icon widget */}
                                        <div className="absolute top-2 right-2 bg-black/60 rounded-full w-6 h-6 flex items-center justify-center opacity-0 group-hover:opacity-100 transition duration-150">
                                          <span className="text-[10px]" title="Quick View">👁️</span>
                                        </div>
                                      </>
                                    )}
                                  </div>
                                  <div className="px-1 relative">
                                    <p className="text-xs font-semibold text-white truncate group-hover:text-[#60cdff] transition">
                                      {sub.title}
                                    </p>
                                    <p className="text-[10px] text-[#60cdff] font-medium">
                                      @{sub.author}
                                    </p>
                                    
                                    {/* Stats pills */}
                                    <div className="flex items-center gap-2 mt-1.5 pt-1.5 border-t border-white/5 text-[9px] text-gray-400">
                                      <span className="flex items-center gap-1">
                                        <Heart className="w-2.5 h-2.5 text-pink-500 fill-pink-500" /> {sub.faves}
                                      </span>
                                      <span className="flex items-center gap-1">
                                        <MessageSquare className="w-2.5 h-2.5" /> {sub.commentsCount}
                                      </span>
                                    </div>
                                  </div>
                                </div>
                              ))}
                            </div>
                          )
                        )}

                        {activeTab === 'notifications' && (
                          <div className="space-y-4">
                            <div className="flex items-center justify-between border-b border-white/5 pb-3">
                              <div>
                                <h4 className="font-bold text-white text-xs">Центр Уведомлений (FAKit Swift Alerts)</h4>
                                <p className="text-[10px] text-gray-400">Активность, парсированная из HTML-запросов Fur Affinity</p>
                              </div>
                              <div className="flex gap-2">
                                <button
                                  onClick={() => {
                                    if (selectedNotifIds.length === 0) return;
                                    setNotifications(prev => prev.filter(n => !selectedNotifIds.includes(n.id)));
                                    setSelectedNotifIds([]);
                                    const msg = "Уведомления успешно архивированы! (POST remove_checked)";
                                    setDownloadToast(msg);
                                    setTimeout(() => setDownloadToast(null), 3000);
                                  }}
                                  disabled={selectedNotifIds.length === 0}
                                  className="bg-red-500/20 text-red-400 hover:bg-red-500/30 disabled:opacity-50 text-[10px] px-2.5 py-1 rounded transition border border-red-500/20 flex items-center gap-1 font-semibold"
                                >
                                  <Trash2 className="w-3 h-3" /> Удалить выбранные
                                </button>
                                <button
                                  onClick={() => {
                                    setNotifications([]);
                                    setSelectedNotifIds([]);
                                    const msg = "Полная очистка уведомлений выполнена! (POST nuke_all)";
                                    setDownloadToast(msg);
                                    setTimeout(() => setDownloadToast(null), 3000);
                                  }}
                                  className="bg-amber-500/10 hover:bg-amber-500/20 text-amber-400 text-[10px] px-2.5 py-1 rounded transition border border-amber-500/20 font-semibold"
                                >
                                  💥 Сбросить всё
                                </button>
                              </div>
                            </div>

                            {notifications.length === 0 ? (
                              <div className="text-center py-12 text-gray-500 text-xs">Все уведомления очищены! Ваша лента пуста 😊</div>
                            ) : (
                              <div className="space-y-2 max-h-[350px] overflow-y-auto pr-1">
                                {notifications.map(notif => {
                                  const isSelected = selectedNotifIds.includes(notif.id);
                                  return (
                                    <div key={notif.id} className="bg-[#2a2a2a]/60 border border-white/5 rounded-lg p-3 flex items-center justify-between gap-3 hover:bg-[#323232]/80 transition text-left">
                                      <div className="flex items-center gap-3">
                                        <input
                                          type="checkbox"
                                          checked={isSelected}
                                          onChange={() => {
                                            setSelectedNotifIds(prev =>
                                              isSelected ? prev.filter(id => id !== notif.id) : [...prev, notif.id]
                                            );
                                          }}
                                          className="rounded bg-black border-white/10 text-[#0078d4]"
                                        />
                                        <div className={`w-8 h-8 rounded-full bg-gradient-to-tr ${notif.avatar} flex items-center justify-center text-[10px] font-bold text-white shadow`}>
                                          {notif.author.substring(0,2).toUpperCase()}
                                        </div>
                                        <div>
                                          <div className="text-xs text-white">
                                            <span className="font-semibold text-[#60cdff]">@{notif.author}</span> {notif.title}
                                          </div>
                                          <div className="text-[9px] text-gray-400 mt-0.5 font-mono">{notif.naturalDatetime} ({notif.datetime})</div>
                                        </div>
                                      </div>
                                      <span className={`text-[9px] uppercase font-mono px-2 py-0.5 rounded ${
                                        notif.type === 'fave' ? 'bg-pink-500/10 text-pink-400 border border-pink-500/20' :
                                        notif.type === 'comment' ? 'bg-[#0078d4]/10 text-[#60cdff] border border-blue-500/20' :
                                        notif.type === 'watch' ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' :
                                        'bg-purple-500/10 text-purple-400 border border-purple-500/20'
                                      }`}>
                                        {notif.type}
                                      </span>
                                    </div>
                                  );
                                })}
                              </div>
                            )}
                          </div>
                        )}

                        {activeTab === 'notes' && (
                          <div className="grid grid-cols-1 md:grid-cols-12 gap-4 h-[350px]">
                            {/* Left col - Conversations list */}
                            <div className="md:col-span-4 border-r border-white/5 pr-3 space-y-2 overflow-y-auto max-h-[350px]">
                              <span className="text-[10px] text-gray-400 uppercase font-bold tracking-wider block text-left">Диалоги ({conversations.length})</span>
                              {conversations.map(conv => {
                                const isSelected = selectedConvId === conv.id;
                                return (
                                  <div
                                    key={conv.id}
                                    onClick={() => {
                                      setSelectedConvId(conv.id);
                                      // Set unread to false when opening!
                                      setConversations(prev => prev.map(c => c.id === conv.id ? { ...c, unread: false } : c));
                                    }}
                                    className={`p-2 rounded-lg border cursor-pointer transition text-left relative ${
                                      isSelected 
                                        ? 'bg-[#0078d4]/10 border-[#60cdff]/30 text-white' 
                                        : 'bg-[#222]/50 border-white/5 hover:bg-[#2a2a2a]/60 text-gray-300'
                                    }`}
                                  >
                                    {conv.unread && (
                                      <span className="absolute top-2.5 right-2 a-dot w-1.5 h-1.5 rounded-full bg-[#60cdff]" />
                                    )}
                                    <div className="flex items-center gap-2">
                                      <div className={`w-6 h-6 rounded-full bg-gradient-to-tr ${conv.avatar} flex items-center justify-center text-[8px] font-bold text-white shadow`} />
                                      <div className="min-w-0 flex-1">
                                        <div className="text-[11px] font-semibold truncate">@{conv.displayAuthor}</div>
                                        <div className="text-[10px] text-gray-400 truncate mt-0.5">{conv.title}</div>
                                      </div>
                                    </div>
                                    <p className="text-[8px] text-gray-500 text-right mt-1">{conv.naturalDatetime}</p>
                                  </div>
                                );
                              })}
                            </div>

                            {/* Right col - Chats viewport */}
                            {(() => {
                              const activeConv = conversations.find(c => c.id === selectedConvId);
                              if (!activeConv) return <div className="md:col-span-8 flex items-center justify-center text-xs text-gray-500">Выберите диалог</div>;
                              return (
                                <div className="md:col-span-8 flex flex-col justify-between h-full bg-black/20 p-2.5 rounded-lg border border-white/5">
                                  {/* Messages viewport */}
                                  <div className="flex-1 overflow-y-auto space-y-2 pr-1 max-h-[260px] mb-2">
                                    {activeConv.messages.map((m, idx) => (
                                      <div key={idx} className={`flex flex-col ${m.sender === 'user' ? 'items-end' : 'items-start'}`}>
                                        <div className={`px-2.5 py-1 rounded-xl text-[11px] max-w-[85%] leading-relaxed text-left ${
                                          m.sender === 'user' 
                                            ? 'bg-[#0078d4] text-white rounded-br-none' 
                                            : 'bg-[#2a2a2e] text-gray-200 rounded-bl-none border border-white/5'
                                        }`}>
                                          {m.text}
                                        </div>
                                        <span className="text-[8px] text-gray-500 mt-0.5 font-mono">{m.time}</span>
                                      </div>
                                    ))}
                                  </div>

                                  {/* Messages form input */}
                                  <form
                                    onSubmit={(e) => {
                                      e.preventDefault();
                                      if (!newReplyText.trim()) return;
                                      
                                      const newMsg: FAMessage = {
                                        sender: 'user',
                                        text: newReplyText.trim(),
                                        time: 'Только что'
                                      };

                                      setConversations(prev => prev.map(c => {
                                        if (c.id === selectedConvId) {
                                          return {
                                            ...c,
                                            messages: [...c.messages, newMsg],
                                            naturalDatetime: 'Только что'
                                          };
                                        }
                                        return c;
                                      }));

                                      setNewReplyText('');

                                      if (soundEnabled) {
                                        setTimeout(() => {
                                          const replyBack: FAMessage = {
                                            sender: 'other',
                                            text: `Спасибо за ответ! Сообщение принято эмулируемым клиентом.`,
                                            time: 'Только что'
                                          };
                                          setConversations(prev => prev.map(c => {
                                            if (c.id === selectedConvId) {
                                              return {
                                                ...c,
                                                messages: [...c.messages, replyBack],
                                                naturalDatetime: 'Только что'
                                              };
                                            }
                                            return c;
                                          }));
                                        }, 1000);
                                      }

                                    }}
                                    className="flex gap-2"
                                  >
                                    <input
                                      type="text"
                                      value={newReplyText}
                                      onChange={(e) => setNewReplyText(e.target.value)}
                                      placeholder="Напишите ответ..."
                                      className="flex-1 bg-white/5 border border-white/10 rounded px-2.5 py-1 text-[11px] text-gray-200 outline-none focus:border-[#60cdff]/50 focus:bg-white/10 transition"
                                    />
                                    <button
                                      type="submit"
                                      className="bg-[#0078d4] hover:bg-[#0078d4]/80 text-white rounded px-2 w-8 flex items-center justify-center transition"
                                    >
                                      <Send className="w-3 h-3" />
                                    </button>
                                  </form>
                                </div>
                              );
                            })()}
                          </div>
                        )}

                        {activeTab === 'settings' && (
                          <div className="space-y-4 max-w-xl mx-auto py-2 text-left">
                            <div className="border-b border-white/5 pb-2">
                              <h4 className="font-bold text-white text-xs">Параметры и Предпочтения (iOS Preferences)</h4>
                              <p className="text-[10px] text-gray-400">Параметры интеграции API и парсинга, портированные из оригинального iOS приложения.</p>
                            </div>

                            <div className="space-y-3">
                              {/* SFW mode switch row */}
                              <div className="flex items-center justify-between bg-white/5 p-2.5 rounded-lg border border-white/5">
                                <div className="space-y-0.5">
                                  <div className="text-[11px] font-semibold text-white flex items-center gap-1.5">
                                    <span>🛡️</span> Безопасный Режим (SFW Mode Filter)
                                  </div>
                                  <p className="text-[10px] text-gray-400">Скрывает взрослые 18+ работы на всех платформах.</p>
                                </div>
                                <button
                                  onClick={() => {
                                    setSfwMode(!sfwMode);
                                    const msg = !sfwMode ? "SFW Фильтр активирован! Взрослый контент скрыт." : "SFW Фильтр отключен! Взрослый контент разблокирован.";
                                    setSfwToast(msg);
                                    setTimeout(() => setSfwToast(null), 3000);
                                  }}
                                  className={`px-2.5 py-1 rounded text-[10px] font-bold transition ${
                                    sfwMode 
                                      ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' 
                                      : 'bg-red-500/10 text-red-400 border border-red-500/20'
                                  }`}
                                >
                                  {sfwMode ? 'ВКЛЮЧЕН (SFW)' : 'ВЫКЛЮЧЕН (18+)'}
                                </button>
                              </div>

                              {/* Image quality select card */}
                              <div className="flex items-center justify-between bg-white/5 p-2.5 rounded-lg border border-white/5">
                                <div className="space-y-0.5">
                                  <div className="text-[11px] font-semibold text-white">🖼️ Качество Изображений (Media Resolution)</div>
                                  <p className="text-[10px] text-gray-400">Выбор разрешения парсинга и предпросмотра.</p>
                                </div>
                                <div className="flex gap-1.5 bg-black/30 p-1 rounded border border-white/5">
                                  {(['low', 'med', 'hd'] as const).map(q => (
                                    <button
                                      key={q}
                                      onClick={() => setImgQuality(q)}
                                      className={`px-2 py-0.5 rounded text-[9px] uppercase font-bold tracking-wide transition-all ${
                                        imgQuality === q 
                                          ? 'bg-[#0078d4] text-white' 
                                          : 'text-gray-400 hover:text-white'
                                      }`}
                                    >
                                      {q}
                                    </button>
                                  ))}
                                </div>
                              </div>

                              {/* Sound enabled toggle */}
                              <div className="flex items-center justify-between bg-white/5 p-2.5 rounded-lg border border-white/5">
                                <div className="space-y-0.5">
                                  <div className="text-[11px] font-semibold text-white">🔊 Автоответчик в чатах</div>
                                  <p className="text-[10px] text-gray-400">Включает автоматические забавные ответы собеседников.</p>
                                </div>
                                <button
                                  onClick={() => setSoundEnabled(!soundEnabled)}
                                  className={`w-9 h-5 rounded-full relative transition duration-150 ${
                                    soundEnabled ? 'bg-[#0078d4]' : 'bg-gray-700'
                                  }`}
                                >
                                  <span className={`w-3.5 h-3.5 bg-white rounded-full absolute top-[3px] transition-all ${
                                    soundEnabled ? 'left-[18px]' : 'left-[3px]'
                                  }`} />
                                </button>
                              </div>

                              {/* Background download toggle */}
                              <div className="flex items-center justify-between bg-white/5 p-2.5 rounded-lg border border-white/5">
                                <div className="space-y-0.5">
                                  <div className="text-[11px] font-semibold text-white">💾 Автоскачивание при лайке</div>
                                  <p className="text-[10px] text-gray-400">Запуск скрытой фоновой загрузки по нажатию кнопки Лайк.</p>
                                </div>
                                <button
                                  onClick={() => setAutoDownloadOnLike(!autoDownloadOnLike)}
                                  className={`w-9 h-5 rounded-full relative transition duration-150 ${
                                    autoDownloadOnLike ? 'bg-[#0078d4]' : 'bg-gray-700'
                                  }`}
                                >
                                  <span className={`w-3.5 h-3.5 bg-white rounded-full absolute top-[3px] transition-all ${
                                    autoDownloadOnLike ? 'left-[18px]' : 'left-[3px]'
                                  }`} />
                                </button>
                              </div>
                            </div>
                          </div>
                        )}

                      </div>

                      {/* Windows status footer */}
                      <footer className="h-7 px-4 bg-[#121212] border-t border-white/5 flex items-center justify-between text-[10px] text-gray-500 font-mono">
                        <div>WinUI 3 Renderer | Nexus Core 2.1.0-alpha</div>
                        <div className="flex gap-4">
                          <span className="text-emerald-500">⚡ Connected to FA Web Scraper API</span>
                          <span>📦 {submissions.length} loaded globally</span>
                        </div>
                      </footer>

                    </div>
                  ) : (
                    /* ANDROID MOBILE PHONE FRAME (Material You concept layout) */
                    <div className="w-[310px] bg-[#141218] border-4 border-slate-700 rounded-[32px] overflow-hidden shadow-2xl flex flex-col min-h-[520px] relative">
                      
                      {/* Speaker / Notch simulator */}
                      <div className="absolute top-2 left-1/2 -translate-x-1/2 w-28 h-4 bg-black rounded-full z-30 flex items-center justify-center">
                        <span className="w-3.5 h-1 bg-slate-800 rounded-full"></span>
                      </div>

                      {/* Header bar - Material 3 Adaptive App Bar */}
                      <div className="bg-[#1d1b20] pt-7 pb-2.5 px-4 flex items-center justify-between relative">
                        <div className="text-left">
                          <span className="font-sans font-bold text-xs text-[#e6e1e6] tracking-tight">FA Nexus</span>
                          <span className="text-[8px] text-[#dbd9ff] font-medium block mt-0.5 uppercase tracking-wider">Material You</span>
                        </div>
                        <div className="flex items-center gap-2 text-[#e6e1e6]">
                          <Search className="w-4 h-4 cursor-pointer text-[#c9c4d0] hover:text-[#e8def8]" onClick={() => setActiveTab('home')} />
                          <button 
                            onClick={() => setIsUploadOpen(true)} 
                            className="bg-[#312e37] hover:bg-[#3b3843] p-1 rounded-full text-[#dbd9ff] transition"
                            title="New Material Upload"
                          >
                            <PlusIcon />
                          </button>
                        </div>
                      </div>

                      {/* Category Quick Chips - Material 3 Quick Filter Chips */}
                      {activeTab === 'home' && (
                        <div className="bg-[#1d1b20] pb-2 px-3 flex gap-1.5 overflow-x-auto scrollbar-none">
                          {(['All', 'Digital', 'Traditional', 'Writing'] as const).map(cat => {
                            const isSelected = selectedCategory === cat;
                            return (
                              <button
                                key={cat}
                                onClick={() => setSelectedCategory(cat)}
                                className={`px-3 py-1 rounded-full text-[10px] font-sans font-medium tracking-wide shrink-0 transition-all ${
                                  isSelected 
                                    ? 'bg-[#e8def8] text-[#1d192b] font-semibold shadow-sm' 
                                    : 'bg-[#1c1b1f] text-[#c9c4d0] border border-[#49454f] hover:bg-white/5'
                                }`}
                              >
                                {cat === 'All' ? 'Все' : cat}
                              </button>
                            );
                          })}
                        </div>
                      )}

                      {/* Mobile phone card stream (HOME) - Material 3 Cards */}
                      {activeTab === 'home' && (
                        <div className="px-3 py-3 flex-1 overflow-y-auto space-y-3 max-h-[380px]" id="mobile-android-stream">
                          {filteredSubmissions.map(sub => (
                            <div
                              key={sub.id}
                              onClick={() => {
                                if (sub.isNsfw && sfwMode) {
                                  setSfwToast(`Контент 18+ скрыт SFW-режимом.`);
                                  setTimeout(() => setSfwToast(null), 3500);
                                } else {
                                  setSelectedSub(sub);
                                }
                              }}
                              className="bg-[#211f26] hover:bg-[#2b2930] rounded-2xl overflow-hidden shadow-sm cursor-pointer transition-all border border-white/5"
                            >
                              {/* Colorful Banner header */}
                              <div className={`h-24 w-full bg-gradient-to-br ${sub.imageGradient} p-2 flex items-end justify-between relative overflow-hidden`}>
                                {sub.isNsfw && sfwMode ? (
                                  <div className="absolute inset-0 bg-black/95 backdrop-blur-md flex flex-col items-center justify-center text-center p-2">
                                    <span className="text-xs">🔞 SFW Filter</span>
                                    <span className="text-[8px] text-zinc-500 uppercase tracking-widest mt-0.5">Взрослый Контент</span>
                                  </div>
                                ) : (
                                  <span className="text-[9px] uppercase tracking-wider bg-[#1d1b20]/80 text-[#e8def8] rounded-md px-2 py-0.5 font-bold z-10 font-sans">
                                    {sub.category}
                                  </span>
                                )}
                              </div>
                              <div className="p-3 space-y-1 text-left">
                                <h5 className="text-xs font-semibold text-[#e6e1e6] truncate">{sub.title}</h5>
                                <p className="text-[10px] text-[#dbd9ff]">@{sub.author}</p>
                                
                                <div className="flex items-center justify-between text-[9px] text-[#c9c4d0] pt-2 border-t border-[#36343b]">
                                  <span>👁 {sub.views}</span>
                                  <div className="flex gap-2.5">
                                    <span className="text-pink-400">❤️ {sub.faves}</span>
                                    <span className="text-[#dbd9ff]">💬 {sub.commentsCount}</span>
                                  </div>
                                </div>
                              </div>
                            </div>
                          ))}
                        </div>
                      )}

                      {/* Mobile phone notifications stream (NOTIFICATIONS) - Material 3 List */}
                      {activeTab === 'notifications' && (
                        <div className="px-3 py-3 flex-1 overflow-y-auto space-y-2 max-h-[380px]" id="mobile-android-notifs">
                          <div className="flex justify-between items-center pb-2 border-b border-[#36343b]">
                            <span className="text-[11px] text-[#dbd9ff] font-bold font-sans">Material Alerts ({notifications.length})</span>
                            <button
                              onClick={() => setNotifications([])}
                              className="text-[9px] text-red-300 font-semibold uppercase tracking-wider hover:text-red-400"
                            >
                              Очистить
                            </button>
                          </div>
                          {notifications.length === 0 ? (
                            <div className="py-12 text-center text-[#c9c4d0] space-y-1">
                              <span className="text-xl">✨</span>
                              <p className="text-[10px] font-sans">Уведомлений нет</p>
                            </div>
                          ) : (
                            <div className="space-y-2">
                              {notifications.map(n => (
                                <div key={n.id} className="bg-[#211f26] border border-white/5 rounded-2xl p-2.5 flex items-start gap-3 text-left hover:bg-[#2b2930] transition-all">
                                  <div className={`w-7 h-7 rounded-full bg-gradient-to-tr ${n.avatar} shrink-0 text-[10px] font-bold flex items-center justify-center text-white shadow-sm`}>
                                    {n.author[0].toUpperCase()}
                                  </div>
                                  <div className="min-w-0 flex-1 space-y-0.5">
                                    <p className="text-[10px] text-[#e6e1e6] leading-snug">
                                      <span className="font-bold text-[#dbd9ff]">@{n.author}</span> {n.title}
                                    </p>
                                    <p className="text-[8px] text-[#c9c4d0] font-sans">{n.naturalDatetime}</p>
                                  </div>
                                </div>
                              ))}
                            </div>
                          )}
                        </div>
                      )}

                      {/* Mobile phone notes stream (NOTES) - Material 3 Mail/Notes */}
                      {activeTab === 'notes' && (
                        <div className="px-2.5 py-3 flex-1 overflow-y-auto max-h-[380px]" id="mobile-android-messages">
                          {selectedConvId ? (
                            /* Active message thread */
                            <div className="flex flex-col h-full bg-[#1c1b1f] p-2 rounded-2xl justify-between gap-2 border border-white/5 animate-fade-in">
                              <button 
                                onClick={() => setSelectedConvId(null)}
                                className="text-left text-[10px] text-[#dbd9ff] font-semibold flex items-center gap-1 hover:underline"
                              >
                                <span>←</span> Назад в Письма
                              </button>
                              <div className="flex-1 overflow-y-auto space-y-2 pr-1 max-h-[220px]">
                                {conversations.find(c => c.id === selectedConvId)?.messages.map((m, idx) => {
                                  const isUser = m.sender === 'user';
                                  return (
                                    <div key={idx} className={`flex flex-col ${isUser ? 'items-end' : 'items-start'}`}>
                                      <p className={`px-3 py-1.5 text-[10px] leading-relaxed max-w-[85%] text-left ${
                                        isUser 
                                          ? 'bg-[#e8def8] text-[#1d192b] rounded-2xl rounded-tr-none shadow-sm' 
                                          : 'bg-[#211f26] text-[#e6e1e6] border border-white/5 rounded-2xl rounded-tl-none'
                                      }`}>
                                        {m.text}
                                      </p>
                                    </div>
                                  );
                                })}
                              </div>
                              <form 
                                onSubmit={(e) => {
                                  e.preventDefault();
                                  if (!newReplyText.trim()) return;
                                  const newMsg = { sender: 'user', text: newReplyText.trim(), time: 'Just now' };
                                  setConversations(prev => prev.map(c => c.id === selectedConvId ? { ...c, messages: [...c.messages, newMsg] } : c));
                                  setNewReplyText('');
                                }}
                                className="flex gap-2 mt-2 border-t border-[#36343b] pt-2"
                              >
                                <input
                                  type="text"
                                  value={newReplyText}
                                  onChange={(e) => setNewReplyText(e.target.value)}
                                  placeholder="Написать ответ..."
                                  className="flex-1 bg-[#211f26] border border-[#49454f] rounded-full px-3 py-1 text-[10px] text-white placeholder-zinc-500 outline-none focus:border-[#e8def8]"
                                />
                                <button type="submit" className="bg-[#e8def8] text-[#1d192b] rounded-full px-2.5 h-6 flex items-center justify-center text-[9px] font-bold hover:opacity-90">SEND</button>
                              </form>
                            </div>
                          ) : (
                            /* Inbox conversation list */
                            <div className="space-y-2">
                              <p className="text-[11px] text-[#dbd9ff] text-left uppercase font-bold tracking-wider font-sans mb-1.5 pl-1">Личные Письма</p>
                              {conversations.map(c => (
                                <div 
                                  key={c.id} 
                                  onClick={() => setSelectedConvId(c.id)}
                                  className="p-3 bg-[#211f26] hover:bg-[#2b2930] rounded-2xl border border-white/5 flex items-center justify-between cursor-pointer transition text-left"
                                >
                                  <div className="flex items-center gap-2.5">
                                    <div className={`w-6 h-6 rounded-full bg-gradient-to-tr ${c.avatar} text-[8px] font-bold flex items-center justify-center text-white shadow-sm`}>
                                      {c.displayAuthor[0].toUpperCase()}
                                    </div>
                                    <div className="min-w-0">
                                      <p className="text-[10px] text-[#e6e1e6] font-semibold truncate">@{c.displayAuthor}</p>
                                      <p className="text-[8px] text-[#c9c4d0] truncate mt-0.5">{c.title}</p>
                                    </div>
                                  </div>
                                  <span className="text-[7px] text-zinc-500">{c.naturalDatetime}</span>
                                </div>
                              ))}
                            </div>
                          )}
                        </div>
                      )}

                      {/* Mobile phone settings stream (SETTINGS) - Material You style */}
                      {activeTab === 'settings' && (
                        <div className="px-3 py-3 flex-1 overflow-y-auto space-y-3 max-h-[380px] text-left animate-fade-in" id="mobile-android-settings">
                          <span className="text-[11px] text-[#dbd9ff] font-bold block font-sans mb-1.5 pl-1">Material Preferences</span>
                          
                          <div className="space-y-3">
                            <div className="bg-[#211f26] p-3 rounded-2xl border border-white/5 space-y-1">
                              <div className="flex items-center justify-between">
                                <span className="text-[10px] text-[#e6e1e6] font-medium">Безопасный Фильтр (SFW)</span>
                                <input 
                                  type="checkbox" 
                                  checked={sfwMode} 
                                  onChange={() => setSfwMode(!sfwMode)}
                                  className="w-4 h-4 rounded text-[#e8def8] focus:ring-0 cursor-pointer accent-[#e8def8]"
                                />
                              </div>
                              <p className="text-[8px] text-[#c9c4d0]">Скрывает взрослые 18+ работы со всех лент.</p>
                            </div>

                            <div className="bg-[#211f26] p-3 rounded-2xl border border-white/5 flex items-center justify-between">
                              <div className="space-y-0.5">
                                <span className="text-[10px] text-[#e6e1e6] font-medium">Preload Quality</span>
                                <p className="text-[8px] text-[#c9c4d0]">Качество загружаемых медиа.</p>
                              </div>
                              <select 
                                value={imgQuality} 
                                onChange={(e) => setImgQuality(e.target.value as any)}
                                className="bg-[#1c1b1f] text-[9px] text-[#e6e1e6] rounded-full border border-[#49454f] px-2 py-1 outline-none"
                              >
                                <option value="low">LOW</option>
                                <option value="med">MED</option>
                                <option value="hd">HD NATIVE</option>
                              </select>
                            </div>

                            <div className="bg-[#211f26] p-3 rounded-2xl border border-white/5 flex items-center justify-between">
                              <div className="space-y-0.5">
                                <span className="text-[10px] text-[#e6e1e6] font-medium">Auto Download on Like</span>
                                <p className="text-[8px] text-[#c9c4d0]">Скачивание по клику на ❤️.</p>
                              </div>
                              <button 
                                onClick={() => setAutoDownloadOnLike(!autoDownloadOnLike)} 
                                className={`text-[8px] px-3 py-1 rounded-full font-bold transition-all ${
                                  autoDownloadOnLike 
                                    ? 'bg-[#e8def8] text-[#1d192b]' 
                                    : 'bg-zinc-700 text-zinc-300'
                                }`}
                              >
                                {autoDownloadOnLike ? 'ON' : 'OFF'}
                              </button>
                            </div>
                          </div>
                        </div>
                      )}

                      {/* Bottom navigation bar - Material 3 Navigation Bar Spec */}
                      <div className="h-16 bg-[#1d1b20] border-t border-[#2d2a31]/60 flex items-center justify-around">
                        {[
                          { tab: 'home', icon: '🏠', label: 'Feed' },
                          { tab: 'notifications', icon: '🔔', label: 'Alerts' },
                          { tab: 'notes', icon: '✉️', label: 'DMs' },
                          { tab: 'settings', icon: '⚙️', label: 'Settings' }
                        ].map(item => {
                          const isSelected = activeTab === item.tab;
                          return (
                            <button
                              key={item.tab}
                              onClick={() => { setActiveTab(item.tab as any); setSelectedSub(null); }}
                              className="flex flex-col items-center justify-center flex-1 py-1 text-center font-sans"
                            >
                              <div className={`px-5 py-1 rounded-full text-xs flex items-center justify-center transition-all duration-200 ${
                                isSelected 
                                  ? 'bg-[#e2dffd] text-[#131032] font-bold scale-105 shadow-sm' 
                                  : 'text-[#c9c4d0] hover:text-white'
                              }`}>
                                <span className="text-xs">{item.icon}</span>
                              </div>
                              <span className={`text-[9px] mt-1 tracking-wide font-medium font-sans ${
                                isSelected ? 'text-white font-semibold' : 'text-[#c9c4d0]'
                              }`}>{item.label}</span>
                            </button>
                          );
                        })}
                      </div>

                    </div>
                  )}

                </div>

              </div>
              
              {/* Submission Grid Info (Click to interact cue) */}
              <div className="bg-[#151515] p-5 rounded-xl border border-white/5 flex flex-col md:flex-row items-center justify-between gap-4">
                <div className="space-y-1 text-center md:text-left">
                  <h4 className="text-sm font-semibold text-white flex items-center gap-2 justify-center md:justify-start">
                    <span className="text-yellow-400">💡</span> Интерактивный Режим
                  </h4>
                  <p className="text-xs text-gray-300">
                    Нажмите на любую карточку работы (например, <strong>Midnight Forest Run</strong> или <strong>Crimson Peak</strong>) выше, запустить детальный просмотр. 
                    Вы сможете имитировать лайки, добавлять комменты и изменять теги в режиме реал-тайма!
                  </p>
                </div>
                <div className="flex gap-2">
                  <button 
                    onClick={() => setIsUploadOpen(true)}
                    className="bg-[#0078d4] hover:bg-[#0078d4]/85 text-xs text-white px-4 py-2 rounded-lg font-bold flex items-center gap-1.5 transition whitespace-nowrap"
                  >
                    <Upload className="w-3.5 h-3.5" /> Создать Свою Загрузку
                  </button>
                </div>
              </div>

            </div>
          )}



          {/* SOURCE BLUEPRINTS TAB */}
          {activeTab === 'blueprints' && (
            <div className="space-y-6">
              <div className="bg-[#121212]/95 rounded-2xl border border-white/5 p-6 shadow-2xl space-y-5">
                
                <div className="border-b border-white/5 pb-4">
                  <div className="flex items-center gap-2">
                    <span className="bg-emerald-500/10 text-emerald-400 text-[10px] uppercase font-mono px-2 py-0.5 rounded border border-emerald-500/20">
                      ZIP Архив Прочитан успешно!
                    </span>
                    <span className="text-gray-400 text-xs">Total: 343 entries, 172 .swift files</span>
                  </div>
                  <h3 className="text-lg md:text-xl font-bold text-white flex items-center gap-2 mt-1">
                    <Code className="w-5 h-5 text-[#60cdff]" /> Сравнение Архитектур: SwiftUI (iOS Native) ➔ Flutter (Dart)
                  </h3>
                  <p className="text-xs text-gray-400 mt-1.5 leading-relaxed">
                    Мы полностью распаковали исходники прикрепленного проекта <strong>FurAffinityApp-main.zip</strong>. 
                    Ниже вы можете в реальном времени сравнить оригинальную реализацию логики парсера/авторизации SwiftUI-клиента с эквивалентным решением на <strong>Flutter (Dart)</strong>.
                  </p>
                </div>

                {/* File Selectors & Language Selector */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {/* File selector column */}
                  <div className="space-y-2">
                    <span className="text-[10px] text-gray-400 uppercase font-bold tracking-wider block">Выберите Модуль для изучения:</span>
                    <div className="grid grid-cols-1 gap-1.5">
                      <button
                        onClick={() => setBlueprintFile('login')}
                        className={`text-left p-3 rounded-xl border transition ${
                          blueprintFile === 'login' 
                            ? 'bg-[#0078d4]/10 border-[#60cdff]/40 text-white font-medium' 
                            : 'bg-[#181818]/80 border-white/5 text-gray-400 hover:bg-white/5 hover:text-gray-200'
                        }`}
                      >
                        <div className="text-xs font-semibold flex items-center gap-2">
                          <span className="text-[10px]">🔑</span> FALoginView
                        </div>
                        <div className="text-[10px] text-gray-500 mt-0.5">
                          Сбор авторизационных куков (a и b) через WebView контейнер.
                        </div>
                      </button>

                      <button
                        onClick={() => setBlueprintFile('submission_page')}
                        className={`text-left p-3 rounded-xl border transition ${
                          blueprintFile === 'submission_page' 
                            ? 'bg-[#0078d4]/10 border-[#60cdff]/40 text-white font-medium' 
                            : 'bg-[#181818]/80 border-white/5 text-gray-400 hover:bg-white/5 hover:text-gray-200'
                        }`}
                      >
                        <div className="text-xs font-semibold flex items-center gap-2">
                          <span className="text-[10px]">📄</span> FASubmissionPage
                        </div>
                        <div className="text-[10px] text-gray-500 mt-0.5">
                          HTML-парсер скрейпинга деталей арта (картины, теги, описание).
                        </div>
                      </button>

                      <button
                        onClick={() => setBlueprintFile('online_session')}
                        className={`text-left p-3 rounded-xl border transition ${
                          blueprintFile === 'online_session' 
                            ? 'bg-[#0078d4]/10 border-[#60cdff]/40 text-white font-medium' 
                            : 'bg-[#181818]/80 border-white/5 text-gray-400 hover:bg-white/5 hover:text-gray-200'
                        }`}
                      >
                        <div className="text-xs font-semibold flex items-center gap-2">
                          <span className="text-[10px]">🌀</span> OnlineFASession
                        </div>
                        <div className="text-[10px] text-gray-500 mt-0.5">
                          Управление сессией, удаление отмеченных уведомлений, Nuke алертов.
                        </div>
                      </button>
                    </div>
                  </div>

                  {/* Language Selector column with Architectural notes */}
                  <div className="bg-[#181818]/80 border border-white/5 rounded-xl p-4 flex flex-col justify-between">
                    <div className="space-y-2">
                      <span className="text-[10px] text-gray-400 uppercase font-bold tracking-wider block">Выбор языка отображения:</span>
                      <div className="flex bg-[#111] p-1 rounded-lg border border-white/5">
                        <button
                          onClick={() => setBlueprintLanguage('dart')}
                          className={`flex-1 text-center py-1.5 rounded-md text-xs font-semibold transition ${
                            blueprintLanguage === 'dart' 
                              ? 'bg-[#0078d4] text-white' 
                              : 'text-gray-400 hover:text-gray-200'
                          }`}
                        >
                          Flutter (Dart) Код
                        </button>
                        <button
                          onClick={() => setBlueprintLanguage('swift')}
                          className={`flex-1 text-center py-1.5 rounded-md text-xs font-semibold transition ${
                            blueprintLanguage === 'swift' 
                              ? 'bg-orange-600 text-white' 
                              : 'text-gray-400 hover:text-gray-200'
                          }`}
                        >
                          Swift (iOS Оригинал)
                        </button>
                      </div>
                    </div>

                    <div className="mt-3 bg-black/40 p-3 rounded-lg border border-white/5 text-[11px] text-gray-300 leading-relaxed">
                      {blueprintFile === 'login' && (
                        <p>
                          <strong>Анализ авторизации:</strong> В SwiftUI-клиенте куки извлекаются через событие <code>onChange(of: cookies)</code> у кастомного WKWebView. 
                          Во Flutter мы добиваемся идентичного результата, опрашивая <code>WebViewCookieManager</code> после загрузки страницы авторизации в контроллере <code>webview_flutter</code>.
                        </p>
                      )}
                      {blueprintFile === 'submission_page' && (
                        <p>
                          <strong>Анализ HTML-разметки:</strong> Swift-код использует библиотеку <code>SwiftSoup</code> для поиска селекторов контента (например, <code>img#submissionImg</code>). 
                          Портированный Flutter-код использует высокопроизводительный пакет <code>html/parser.dart</code>, реализуя точно такие же CSS-селекторы.
                        </p>
                      )}
                      {blueprintFile === 'online_session' && (
                        <p>
                          <strong>Управление сессией:</strong> Как Swift, так и Flutter отправляют POST-запросы напрямую на эндпоинты Fur Affinity (например, <code>messagecenter-action: remove_checked</code>), 
                          подставляя куки сессии <code>a</code> и <code>b</code> в заголовки вызова.
                        </p>
                      )}
                    </div>
                  </div>
                </div>

                {/* Source Viewport with Title */}
                <div className="bg-[#181818] rounded-xl border border-white/5 overflow-hidden">
                  <div className="bg-black/40 p-3 border-b border-white/5 flex items-center justify-between text-xs font-mono">
                    <div className="flex items-center gap-2">
                      <span className={`w-2 h-2 rounded-full ${blueprintLanguage === 'dart' ? 'bg-cyan-400' : 'bg-orange-500'}`} />
                      <span className="text-gray-300">
                        {blueprintFile === 'login' && (blueprintLanguage === 'dart' ? 'fa_login_webview.dart' : 'FALoginView.swift')}
                        {blueprintFile === 'submission_page' && (blueprintLanguage === 'dart' ? 'fa_submission_page.dart' : 'FASubmissionPage.swift')}
                        {blueprintFile === 'online_session' && (blueprintLanguage === 'dart' ? 'online_fa_session.dart' : 'OnlineFASession.swift')}
                      </span>
                    </div>
                    <span className="text-gray-500 capitalize">{blueprintLanguage} source format</span>
                  </div>

                  <pre className="p-4 text-[10.5px] font-mono text-gray-200 overflow-x-auto leading-relaxed max-h-[500px] overflow-y-auto bg-black/60">
                    {blueprintFile === 'login' && blueprintLanguage === 'swift' && (
`// Исходный SwiftUI код из FALoginView.swift
import SwiftUI
import FAPages
import WebKit

public struct FALoginView: View {
    @Binding var session: OnlineFASession?
    var onError: (Error) -> Void
    @State private var cookies = [HTTPCookie]()
    
    public var body: some View {
        WebView(initialUrl: FAURLs.homeUrl.appendingPathComponent("login"),
                cookies: $cookies,
                clearCookies: true)
            .onChange(of: cookies) { _, newCookies in
                Task {
                    guard session == nil else { return }
                    do {
                        // Кастомный парсинг сессии после извлечения cookies 'a' и 'b'
                        session = try await Self.makeSession(cookies: newCookies)
                    } catch {
                        onError(error)
                    }
                }
            }
    }
}`
                    )}

                    {blueprintFile === 'login' && blueprintLanguage === 'dart' && (
`// Портированный Flutter (Dart) эквивалент извлечения cookies
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class FALoginWebView extends StatefulWidget {
  final Function(Map<String, String>) onCookiesCaptured;
  const FALoginWebView({Key? key, required this.onCookiesCaptured}) : super(key: key);

  @override
  State<FALoginWebView> createState() => _FALoginWebViewState();
}

class _FALoginWebViewState extends State<FALoginWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            // Читаем все куки для домена furaffinity.net
            final cookieManager = WebViewCookieManager();
            final cookies = await cookieManager.getCookies(Uri.parse('https://www.furaffinity.net'));
            
            final Map<String, String> creds = {};
            for (var cookie in cookies) {
              if (cookie.name == 'a' || cookie.name == 'b') {
                creds[cookie.name] = cookie.value;
              }
            }
            
            // Если оба основных кука авторизации у нас - сессия успешна!
            if (creds.containsKey('a') && creds.containsKey('b')) {
              widget.onCookiesCaptured(creds);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.furaffinity.net/login'));
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}`
                    )}

                    {blueprintFile === 'submission_page' && blueprintLanguage === 'swift' && (
`// Исходный SwiftSoup HTML parsing код из FASubmissionPage.swift
import Foundation
import SwiftSoup

public struct FASubmissionPage: FAPage {
    public let previewImageUrl: URL
    public let fullResolutionMediaUrl: URL
    public let htmlDescription: String
    public let isFavorite: Bool
    
    public init(data: Data, url: URL) throws {
        let doc = try SwiftSoup.parse(String(decoding: data, as: UTF8.self))
        
        let submissionMainQuery = "body#pageid-submission div#main-window div#site-content div#submission_page div div.submission-page-content div#submission-main-content"
        let mainNode = try doc.select(submissionMainQuery)
        
        // Маунт картинок предпросмотра и оригинала
        let imgNode = try mainNode.select("div div.submission-content div.submission-area img#submissionImg")
        let previewStr = try imgNode.attr("data-preview-src")
        let fullViewStr = try imgNode.attr("data-fullview-src")
        
        self.previewImageUrl = try URL(unsafeString: "https:" + previewStr)
        self.fullResolutionMediaUrl = try URL(unsafeString: "https:" + fullViewStr)
        
        // Парсинг лайкнутости
        let favoriteNode = try mainNode.select("div#submission-options a.button")
        let textVal = try favoriteNode.first(where: { ["+Fav", "-Fav"].contains(try $0.text()) })?.text()
        self.isFavorite = textVal == "-Fav"
        
        // Разметка описания
        let descriptionNode = try mainNode.select("section.submission-description div.submission-description-text")
        self.htmlDescription = try descriptionNode.html()
    }
}`
                    )}

                    {blueprintFile === 'submission_page' && blueprintLanguage === 'dart' && (
`// Портированный Flutter (Dart) парсер через package:html/parser.dart
import 'package:html/parser.dart' show parse;

class FASubmissionPage {
  final String previewImageUrl;
  final String fullResolutionMediaUrl;
  final String htmlDescription;
  final bool isFavorite;
  final String title;

  FASubmissionPage({
    required this.previewImageUrl,
    required this.fullResolutionMediaUrl,
    required this.htmlDescription,
    required this.isFavorite,
    required this.title,
  });

  /// Разбор HTML страницы одиночной работы
  factory FASubmissionPage.fromHtml(String htmlString) {
    final document = parse(htmlString);
    
    // Полноценный селектор картинки
    final submissionImg = document.querySelector('img#submissionImg');
    final previewSrc = submissionImg?.attributes['data-preview-src'] ?? '';
    final fullSrc = submissionImg?.attributes['data-fullview-src'] ?? '';

    // Ссылка на "Убрать из Избранного" (-Fav) или добавить "+Fav"
    final favButton = document.querySelectorAll('div#submission-options a.button')
        .firstWhere((el) => el.text.contains('+Fav') || el.text.contains('-Fav'), 
        orElse: () => throw Exception('Fav button not found'));
    final isFav = favButton.text.trim() == '-Fav';

    // HTML Описание
    final descElement = document.querySelector('div.submission-description-text');
    final htmlDesc = descElement?.innerHtml ?? '';

    // Заголовок арта
    final titleElement = document.querySelector('div.submission-title h2');
    final titleStr = titleElement?.text?.trim() ?? '';

    return FASubmissionPage(
      previewImageUrl: 'https:$previewSrc',
      fullResolutionMediaUrl: 'https:$fullSrc',
      htmlDescription: htmlDesc,
      isFavorite: isFav,
      title: titleStr,
    );
  }
}`
                    )}

                    {blueprintFile === 'online_session' && blueprintLanguage === 'swift' && (
`// Исходный swift управление сессией из OnlineFASession.swift
import Foundation

public class OnlineFASession: FASession {
    public let username: String
    private let cookies: [HTTPCookie]
    private let dataSource: HTTPDataSource
    
    /// Очистка уведомлений по POST-запросу
    public func deleteSubmissionPreviews(_ previews: [FASubmissionPreview]) async throws {
        let url = try FAURLs.submissionsUrl(from: previews.max().unwrap().sid)
        var params: [URLQueryItem] = [
            .init(name: "messagecenter-action", value: "remove_checked")
        ]
        // Сбор массива submissions[] для отправки формы удаления
        for preview in previews {
            params.append(URLQueryItem(name: "submissions[]", value: "\\(preview.id)"))
        }
        
        let data = try await dataSource.httpData(from: url, cookies: cookies, method: .POST, parameters: params)
    }
    
    /// Полный nuke (удаление всех алертов одной кнопкой)
    public func nukeSubmissions() async throws {
        let url = FAURLs.latest72SubmissionsUrl
        let params: [URLQueryItem] = [
            .init(name: "messagecenter-action", value: "nuke_notifications")
        ]
        let data = try await dataSource.httpData(from: url, cookies: cookies, method: .POST, parameters: params)
    }
}`
                    )}

                    {blueprintFile === 'online_session' && blueprintLanguage === 'dart' && (
`// Портированный Flutter (Dart) сессионный сервис
import 'package:http/http.dart' as http;

class OnlineFASession {
  final String sessionA; // Cookie a
  final String sessionB; // Cookie b
  final String username;

  OnlineFASession({
    required this.sessionA, 
    required this.sessionB, 
    required this.username
  });

  Map<String, String> get headers => {
    'User-Agent': 'FurAffinityNexus/3.0 (Flutter Multiplatform)',
    'Cookie': 'a=$sessionA; b=$sessionB;',
  };

  /// Удаление выбранных превьюшек-уведомлений
  Future<bool> deleteSubmissionNotifications(List<String> ids, String maxSid) async {
    final url = Uri.parse('https://www.furaffinity.net/msg/submissions/new/from-$maxSid/');
    
    final Map<String, String> body = {
      'messagecenter-action': 'remove_checked',
    };
    for (int i = 0; i < ids.length; i++) {
      body['submissions[$i]'] = ids[i];
    }

    final response = await http.post(url, headers: headers, body: body);
    return response.statusCode == 200;
  }

  /// Полное удаление (Nuke) всех уведомлений о работах
  Future<bool> nukeSubmissions() async {
    final url = Uri.parse('https://www.furaffinity.net/msg/submissions/new/');
    final response = await http.post(
      url, 
      headers: headers, 
      body: {
        'messagecenter-action': 'nuke_notifications',
      }
    );
    return response.statusCode == 200;
  }
}`
                    )}
                  </pre>
                </div>

                <div className="bg-[#1c1c1c] p-4 rounded-xl border border-white/5 space-y-2 text-xs">
                  <span className="font-semibold text-emerald-400 flex items-center gap-1.5">
                    <span>💡</span> Архитектурные Рекомендации по Интеграции в Flutter
                  </span>
                  <p className="text-gray-300 leading-relaxed text-[11px]">
                    При портировании парсинг-модулей из декомпа iOS на Flutter, обратите внимание на стабильность парсинга HTML. 
                    Оригинальное Swift-приложение использует строгие селекторы Jsoup. Мы рекомендуем обернуть разбор во Flutter в блоки 
                    <code>try-catch</code> и возвращать дефолтные пустые объекты при изменении верстки Fur Affinity, чтобы приложение не вылетало в продакшене.
                  </p>
                </div>

              </div>
            </div>
          )}


        </div>

      </div>

      {/* DETAILED DIALOG MODAL: For exploring individual Fur Affinity submissions */}
      {selectedSub && (
        <div className="fixed inset-0 z-50 bg-black/85 flex items-center justify-center p-4 backdrop-blur-sm animate-fade-in text-xs">
          <div className="bg-[#181818] border border-white/10 rounded-2xl max-w-2xl w-full text-gray-200 overflow-hidden shadow-2xl flex flex-col max-h-[90vh]">
            
            {/* Modal header details */}
            <div className="p-4 bg-black/40 border-b border-white/5 flex items-center justify-between">
              <div>
                <span className="text-[10px] text-[#60cdff] uppercase font-mono tracking-wide">{selectedSub.category} Art Piece</span>
                <h4 className="text-base font-bold text-white">{selectedSub.title}</h4>
              </div>
              <button 
                onClick={() => setSelectedSub(null)}
                className="p-1 px-2.5 rounded bg-white/5 hover:bg-white/10 text-gray-400 hover:text-white transition"
              >
                ✕ Закрыть
              </button>
            </div>

            {/* Modal Content Scroll body */}
            <div className="p-5 overflow-y-auto space-y-4 flex-1">
              
              {/* Grand Visual Preview using our gradients representing FA uploads */}
              <div className={`h-64 rounded-xl bg-gradient-to-br ${selectedSub.imageGradient} flex flex-col items-center justify-center text-center p-6 relative overflow-hidden group shadow-inner border border-white/5`}>
                <div className="absolute inset-0 bg-black/10 transition-all rounded" />
                <span className="z-10 text-white/40 text-xs font-mono tracking-widest uppercase block border border-white/5 bg-black/50 px-3 py-1 rounded">
                  {selectedSub.title} • {selectedSub.category} Viewport
                </span>
                <span className="z-10 absolute bottom-3 right-3 text-[9px] text-[#60cdff] bg-black/75 px-2 py-0.5 rounded font-mono">
                  @{selectedSub.author}
                </span>
              </div>

              {/* Action Buttons: Favorites, Share, Download and stats */}
              <div className="flex flex-col gap-3 py-2 border-y border-white/5 text-gray-300">
                <div className="flex flex-wrap gap-2.5 items-center justify-between">
                  {/* Left column action buttons */}
                  <div className="flex flex-wrap gap-2">
                    <span className="flex items-center gap-1 bg-white/5 border border-white/5 px-2.5 py-1 rounded text-xs select-none">
                      👁️ {selectedSub.views} Просмотров
                    </span>
                    
                    <button 
                      onClick={() => handleToggleFave(selectedSub.id)}
                      className="flex items-center gap-1.5 bg-pink-700/20 hover:bg-pink-700/30 text-pink-400 px-3 py-1 rounded text-xs transition border border-pink-500/20 active:scale-95"
                    >
                      <Heart className="w-3.5 h-3.5 fill-pink-500" /> {selectedSub.faves} В Избранное
                    </button>

                    <button 
                      onClick={() => handleShare(selectedSub)}
                      className="flex items-center gap-1.5 bg-[#0078d4]/15 hover:bg-[#0078d4]/30 text-[#60cdff] px-3 py-1 rounded text-xs transition border border-[#60cdff]/20 active:scale-95"
                      title="Копировать прямую ссылку на Fur Affinity"
                    >
                      <Share2 className="w-3.5 h-3.5" /> Поделиться
                    </button>

                    <button 
                      onClick={() => handleDownload(selectedSub)}
                      disabled={downloadingPercent !== null}
                      className="flex items-center gap-1.5 bg-emerald-700/15 hover:bg-emerald-700/30 text-emerald-400 px-3 py-1 rounded text-xs transition border border-emerald-500/20 disabled:opacity-50 active:scale-95"
                      title="Скачать оригинальный файл изображения"
                    >
                      <Download className="w-3.5 h-3.5" /> 
                      {downloadingPercent !== null ? `Скачивание ${downloadingPercent}%` : 'Скачать HD'}
                    </button>
                  </div>

                  {/* Right column published date */}
                  <div className="text-[10px] text-gray-400 font-mono">
                    Опубликовано: {selectedSub.date}
                  </div>
                </div>

                {/* Sub-actions Toast Messages inside the details block */}
                {(shareToast || downloadToast) && (
                  <div className="bg-[#111] border border-white/10 p-2.5 rounded-lg flex flex-col gap-1.5 animate-fade-in">
                    {shareToast && (
                      <div className="text-[#60cdff] flex items-center gap-2">
                        <span className="w-1.5 h-1.5 rounded-full bg-[#60cdff] inline-block animate-ping"></span>
                        <span className="font-semibold">Share:</span>
                        <span>{shareToast}</span>
                      </div>
                    )}
                    {downloadToast && (
                      <div className="text-emerald-400 flex items-center gap-2">
                        <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 inline-block animate-ping"></span>
                        <span className="font-semibold">Download:</span>
                        <span>{downloadToast}</span>
                      </div>
                    )}
                  </div>
                )}
              </div>

              {/* Creator comment description block */}
              <div className="space-y-1.5">
                <h5 className="font-bold text-white text-xs">Описание Автора:</h5>
                <p className="text-gray-300 leading-relaxed bg-[#202020]/40 p-3.5 rounded-lg border border-white/5 whitespace-pre-line text-[11px]">
                  {selectedSub.description}
                </p>
              </div>

              {/* Tags panel */}
              <div className="space-y-1.5">
                <h5 className="font-bold text-white text-xs">Ключевые слова (Теги):</h5>
                <div className="flex flex-wrap gap-1.5">
                  {selectedSub.tags.map((tag, i) => (
                    <span 
                      key={i} 
                      onClick={() => {
                        setSearchQuery(tag);
                        setSelectedSub(null);
                      }} 
                      className="bg-[#242424] hover:bg-white/5 text-[10px] text-[#60cdff] px-2 py-0.5 rounded cursor-pointer transition border border-white/5"
                    >
                      #{tag}
                    </span>
                  ))}
                </div>
              </div>

              {/* Inline Comments section */}
              <div className="space-y-3 pt-3 border-t border-white/5">
                <h5 className="font-bold text-white text-xs flex items-center justify-between">
                  <span>Комментарии ({selectedSub.comments.length})</span>
                  <span className="text-[10px] text-gray-500 font-normal">Синхронизировано локально</span>
                </h5>

                {selectedSub.comments.length === 0 ? (
                  <p className="text-[11px] text-gray-500 italic py-2">Здесь пока нет комментариев. Напишите первый под своим аккаунтом!</p>
                ) : (
                  <div className="space-y-2.5">
                    {selectedSub.comments.map((comm) => (
                      <div key={comm.id} className="bg-black/25 p-2.5 rounded border border-white/5 text-[11px] space-y-1">
                        <div className="flex justify-between items-center">
                          <span className="font-bold text-indigo-300">@{comm.author}</span>
                          <span className="text-[10px] text-gray-500 font-mono">{comm.time}</span>
                        </div>
                        <p className="text-gray-300">{comm.text}</p>
                      </div>
                    ))}
                  </div>
                )}

                {/* Submit input */}
                <form onSubmit={handleAddComment} className="flex gap-2 items-center pt-2">
                  <input
                    type="text"
                    value={commentText}
                    onChange={(e) => setCommentText(e.target.value)}
                    placeholder="Напишите ответ от лица SilverVulpine..."
                    className="flex-1 bg-white/5 border border-white/10 rounded-lg p-2 text-xs text-gray-200 outline-none focus:border-[#60cdff]/60"
                  />
                  <button 
                    type="submit"
                    className="bg-[#0078d4] text-white p-2 rounded-lg hover:bg-[#0078d4]/85 transition"
                  >
                    <Send className="w-3.5 h-3.5" />
                  </button>
                </form>
              </div>

            </div>

            {/* Close actions */}
            <div className="p-3.5 bg-black/40 border-t border-white/5 text-right">
              <button
                onClick={() => setSelectedSub(null)}
                className="bg-white/5 text-gray-300 hover:bg-white/10 font-bold px-4 py-1.5 rounded-lg text-xs"
              >
                Закрыть окно
              </button>
            </div>
          </div>
        </div>
      )}

      {/* DYNAMIC UPLOAD MODAL: Usability Patterns for file uploading / custom generator */}
      {isUploadOpen && (
        <div className="fixed inset-0 z-50 bg-black/85 flex items-center justify-center p-4 backdrop-blur-sm animate-fade-in text-xs">
          <div className="bg-[#181818] border border-white/10 rounded-2xl max-w-lg w-full text-gray-200 overflow-hidden shadow-2xl flex flex-col">
            
            <div className="p-4 bg-black/40 border-b border-white/5 flex items-center justify-between">
              <h4 className="text-sm font-bold text-white flex items-center gap-2">
                <Upload className="w-4 h-4 text-[#60cdff]" /> Имитация Загрузки в Галерею FA Nexus
              </h4>
              <button 
                onClick={() => setIsUploadOpen(false)}
                className="text-gray-400 hover:text-white"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleCreateUpload} className="p-5 space-y-4">
              
              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1">
                  <label className="text-gray-400 text-[11px] font-bold block">Название работы:</label>
                  <input
                    required
                    type="text"
                    value={newTitle}
                    onChange={(e) => setNewTitle(e.target.value)}
                    placeholder="Прим: Golden Forest Cabin"
                    className="w-full bg-white/5 border border-white/10 rounded p-2 text-xs text-white outline-none focus:border-[#60cdff]"
                  />
                </div>
                <div className="space-y-1">
                  <label className="text-gray-400 text-[11px] font-bold block">Ваш Псевдоним:</label>
                  <input
                    required
                    type="text"
                    value={newArtist}
                    onChange={(e) => setNewArtist(e.target.value)}
                    placeholder="Прим: AeroWolf"
                    className="w-full bg-white/5 border border-white/10 rounded p-2 text-xs text-white outline-none focus:border-[#60cdff]"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1">
                  <label className="text-gray-400 text-[11px] font-bold block">Категория Медиа:</label>
                  <select
                    value={newCategory}
                    onChange={(e) => setNewCategory(e.target.value as any)}
                    className="w-full bg-[#202020] border border-white/10 rounded p-1.5 text-xs text-white outline-none"
                  >
                    <option value="Digital">Digital Art</option>
                    <option value="Traditional">Traditional Art</option>
                    <option value="Writing">Writing / Prose</option>
                  </select>
                </div>
                
                <div className="space-y-1">
                  <label className="text-gray-400 text-[11px] font-bold block">Градиент Наброска:</label>
                  <select
                    value={newGradient}
                    onChange={(e) => setNewGradient(e.target.value)}
                    className="w-full bg-[#202020] border border-white/10 rounded p-1.5 text-xs text-white outline-none"
                  >
                    {gradientPresets.map((preset, idx) => (
                      <option key={idx} value={preset.value}>
                        {preset.label}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="space-y-1">
                <label className="text-gray-400 text-[11px] font-bold block">Описание:</label>
                <textarea
                  value={newDescription}
                  onChange={(e) => setNewDescription(e.target.value)}
                  placeholder="Опишите в деталях вашу художественную работу, идеи или концепт..."
                  rows={3}
                  className="w-full bg-white/5 border border-white/10 rounded p-2 text-xs text-white outline-none focus:border-[#60cdff] resize-none"
                />
              </div>

              <div className="space-y-1">
                <label className="text-gray-400 text-[11px] font-bold block">Облако Тегов (через запятую):</label>
                <input
                  type="text"
                  value={newTagsStr}
                  onChange={(e) => setNewTagsStr(e.target.value)}
                  placeholder="wolf, anthro, cabin, forest, commission"
                  className="w-full bg-white/5 border border-white/10 rounded p-2 text-xs text-white outline-none focus:border-[#60cdff]"
                />
                <span className="text-[9px] text-gray-500">Автоматически парсирует в кликабельные элементы</span>
              </div>

              <div className="pt-2 border-t border-white/5 flex justify-end gap-2.5">
                <button
                  type="button"
                  onClick={() => setIsUploadOpen(false)}
                  className="bg-white/5 text-gray-300 hover:bg-white/10 font-bold px-4 py-1.5 rounded-lg text-xs"
                >
                  Отмена
                </button>
                <button
                  type="submit"
                  className="bg-[#0078d4] text-white font-bold px-4 py-1.5 rounded-lg text-xs hover:bg-[#0078d4]/85 shadow transition"
                >
                  Опубликовать Локально
                </button>
              </div>

            </form>

          </div>
        </div>
      )}
      
      {/* Dynamic Background Downloads Queue Panel */}
      {activeDownloads.length > 0 && (
        <div className="fixed bottom-6 right-6 z-50 bg-[#161616]/95 border border-white/10 rounded-xl p-4 shadow-2xl backdrop-blur-md w-80 animate-fade-in text-xs text-white">
          <div className="flex items-center justify-between pb-2 border-b border-white/5 mb-2.5">
            <div className="flex items-center gap-2 text-cyan-400 font-semibold">
              <span className="w-2 h-2 rounded-full bg-[#60cdff] block animate-pulse"></span>
              <span>Фоновые загрузки FA ({activeDownloads.length})</span>
            </div>
            <span className="text-[10px] text-gray-400">В процессе...</span>
          </div>
          <div className="space-y-3 max-h-52 overflow-y-auto">
            {activeDownloads.map((dl) => (
              <div key={dl.id} className="space-y-1">
                <div className="flex justify-between text-[11px] text-gray-300">
                  <span className="truncate font-medium max-w-[180px]" title={dl.title}>
                    {dl.triggerType === 'like' ? '❤️ Авто: ' : '💾 HD: '} {dl.title}
                  </span>
                  <span className="text-gray-400 font-mono text-[10px]">{dl.percent}%</span>
                </div>
                <div className="w-full bg-white/5 h-1.5 rounded-full overflow-hidden border border-white/5">
                  <div 
                    className={`h-full transition-all duration-150 rounded-full ${
                      dl.triggerType === 'like' ? 'bg-pink-500' : 'bg-emerald-500'
                    }`}
                    style={{ width: `${dl.percent}%` }}
                  />
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

    </div>
  );
}

// Mini inline helpers to avoid external package import bloat
function PlusIcon() {
  return (
    <svg className="w-4.5 h-4.5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M12 4v16m8-8H4" />
    </svg>
  );
}
