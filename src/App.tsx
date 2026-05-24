import { useState, useMemo } from 'react';
import React from 'react';
import {
  Search,
  X,
  Heart,
  MessageSquare,
  Clock,
  Loader,
  AlertCircle,
  LogOut,
  LogIn,
  RefreshCw,
} from 'lucide-react';
import { useSubmissions, useSubmissionDetails, useComments, useSearch, useNotifications, useAuth } from './hooks/useFA';

export default function App() {
  const [activeTab, setActiveTab] = useState<'home' | 'notifications' | 'search' | 'settings' | 'login'>('home');
  const [selectedSub, setSelectedSub] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<'All' | 'Digital' | 'Traditional' | 'Writing'>('All');
  const [currentPage, setCurrentPage] = useState(1);
  const [sfwMode, setSfwMode] = useState(true);

  // Real data hooks
  const { submissions, loading: subsLoading, error: subsError } = useSubmissions(currentPage, selectedCategory.toLowerCase());
  const { submission: selectedSubmission, loading: subLoading } = useSubmissionDetails(selectedSub);
  const { comments: subComments, loading: commentsLoading } = useComments(selectedSub);
  const { results: searchResults, loading: searchLoading } = useSearch(searchQuery);
  const { session, login, logout, loading: authLoading, error: authError } = useAuth();
  const { notifications, refresh: refreshNotifications } = useNotifications(session?.username || null);

  // Login state
  const [loginUsername, setLoginUsername] = useState('');
  const [loginPassword, setLoginPassword] = useState('');

  const handleLogin = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const result = await login(loginUsername, loginPassword);
    if (result) {
      setLoginUsername('');
      setLoginPassword('');
      setActiveTab('home');
    }
  };

  const filteredSubmissions = useMemo(() => {
    return (searchQuery ? searchResults : submissions).filter(sub => {
      const matchesSearch = sub.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        sub.author.toLowerCase().includes(searchQuery.toLowerCase()) ||
        sub.tags.some(t => t.toLowerCase().includes(searchQuery.toLowerCase()));
      return matchesSearch;
    });
  }, [submissions, searchResults, searchQuery]);

  return (
    <div className="min-h-screen bg-[#090909] text-gray-200 antialiased font-sans">
      {!session ? (
        // Login Screen
        <div className="flex items-center justify-center min-h-screen p-4">
          <div className="bg-[#1a1a1a] border border-white/10 rounded-xl p-8 max-w-md w-full shadow-2xl space-y-6">
            <div className="text-center space-y-2">
              <div className="w-12 h-12 mx-auto rounded-lg bg-[#0078d4] flex items-center justify-center text-lg font-bold text-white">
                FA
              </div>
              <h1 className="text-2xl font-bold text-white">FA Nexus</h1>
              <p className="text-sm text-gray-400">Fur Affinity Client</p>
            </div>

            <form onSubmit={handleLogin} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-1">
                  Username
                </label>
                <input
                  type="text"
                  value={loginUsername}
                  onChange={(e) => setLoginUsername(e.target.value)}
                  placeholder="Enter your FA username"
                  className="w-full bg-[#2a2a2a] border border-white/10 rounded px-3 py-2 text-white placeholder-gray-500 focus:border-[#60cdff] outline-none transition"
                  disabled={authLoading}
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-300 mb-1">
                  Password
                </label>
                <input
                  type="password"
                  value={loginPassword}
                  onChange={(e) => setLoginPassword(e.target.value)}
                  placeholder="Enter your password"
                  className="w-full bg-[#2a2a2a] border border-white/10 rounded px-3 py-2 text-white placeholder-gray-500 focus:border-[#60cdff] outline-none transition"
                  disabled={authLoading}
                />
              </div>

              {authError && (
                <div className="flex gap-2 p-3 bg-red-500/10 border border-red-500/20 rounded text-red-400 text-sm">
                  <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
                  <span>{authError}</span>
                </div>
              )}

              <button
                type="submit"
                disabled={authLoading || !loginUsername || !loginPassword}
                className="w-full bg-[#0078d4] hover:bg-[#0078d4]/80 disabled:opacity-50 text-white font-semibold py-2 rounded transition flex items-center justify-center gap-2"
              >
                {authLoading ? (
                  <>
                    <Loader className="w-4 h-4 animate-spin" />
                    Logging in...
                  </>
                ) : (
                  <>
                    <LogIn className="w-4 h-4" />
                    Login
                  </>
                )}
              </button>
            </form>

            <p className="text-xs text-gray-500 text-center">
              Your credentials are only used for this session
            </p>
          </div>
        </div>
      ) : (
        // Main App
        <div className="p-4 md:p-8 flex flex-col items-center justify-start gap-6 min-h-screen">
          {/* Header */}
          <div className="w-full max-w-6xl mx-auto bg-gradient-to-r from-cyan-950/40 via-blue-950/40 to-slate-900/40 border border-[#60cdff]/20 rounded-xl p-5 shadow-2xl backdrop-blur-md">
            <div className="flex items-center justify-between gap-4 flex-wrap">
              <div className="space-y-1">
                <div className="flex items-center gap-2">
                  <div className="w-8 h-8 rounded-lg bg-[#0078d4] flex items-center justify-center font-bold text-white text-xs">
                    FA
                  </div>
                  <h1 className="text-2xl font-bold text-white">FA Nexus</h1>
                </div>
                <p className="text-sm text-gray-300">Welcome, <span className="text-[#60cdff] font-semibold">@{session.username}</span></p>
              </div>

              <div className="flex items-center gap-3">
                <button
                  onClick={logout}
                  className="bg-red-500/20 text-red-400 hover:bg-red-500/30 px-3 py-1.5 rounded text-sm font-semibold flex items-center gap-1.5 transition"
                >
                  <LogOut className="w-4 h-4" />
                  Logout
                </button>
              </div>
            </div>

            {/* Navigation Tabs */}
            <div className="flex gap-2 mt-4 border-t border-white/10 pt-4 overflow-x-auto">
              {['home', 'notifications', 'search', 'settings'].map(tab => (
                <button
                  key={tab}
                  onClick={() => {
                    setActiveTab(tab as any);
                    setSelectedSub(null);
                  }}
                  className={`px-4 py-2 rounded text-sm font-medium whitespace-nowrap transition ${
                    activeTab === tab
                      ? 'bg-[#0078d4]/20 text-[#60cdff] border border-[#60cdff]/30'
                      : 'text-gray-400 hover:text-white hover:bg-white/5'
                  }`}
                >
                  {tab === 'home' && '🏠 Gallery'}
                  {tab === 'notifications' && '🔔 Notifications'}
                  {tab === 'search' && '🔍 Search'}
                  {tab === 'settings' && '⚙️ Settings'}
                </button>
              ))}
            </div>
          </div>

          {/* Content Area */}
          <div className="w-full max-w-6xl mx-auto">
            {/* Gallery Tab */}
            {activeTab === 'home' && (
              <div className="bg-[#121212]/95 rounded-2xl border border-white/5 shadow-2xl p-6 space-y-6">
                {/* Search and Filters */}
                <div className="flex flex-col gap-4">
                  <div className="flex items-center px-3 py-2 rounded bg-white/5 border border-white/10 gap-2">
                    <Search className="w-4 h-4 text-gray-400 shrink-0" />
                    <input
                      type="text"
                      value={searchQuery}
                      onChange={(e) => {
                        setSearchQuery(e.target.value);
                        setCurrentPage(1);
                      }}
                      placeholder="Search submissions..."
                      className="bg-transparent border-none outline-none text-sm text-white placeholder-gray-500 flex-1"
                    />
                    {searchQuery && (
                      <button onClick={() => setSearchQuery('')}>
                        <X className="w-4 h-4 text-gray-400 hover:text-white" />
                      </button>
                    )}
                  </div>

                  <div className="flex gap-2 overflow-x-auto">
                    {(['All', 'Digital', 'Traditional', 'Writing'] as const).map(cat => (
                      <button
                        key={cat}
                        onClick={() => {
                          setSelectedCategory(cat);
                          setCurrentPage(1);
                        }}
                        className={`px-3 py-1 rounded text-sm font-medium whitespace-nowrap transition ${
                          selectedCategory === cat
                            ? 'bg-[#0078d4]/20 text-[#60cdff] border border-[#60cdff]/30'
                            : 'bg-white/5 text-gray-400 hover:text-white'
                        }`}
                      >
                        {cat}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Error State */}
                {subsError && (
                  <div className="flex gap-2 p-4 bg-red-500/10 border border-red-500/20 rounded text-red-400 text-sm">
                    <AlertCircle className="w-5 h-5 shrink-0" />
                    <span>{subsError}</span>
                  </div>
                )}

                {/* Loading State */}
                {subsLoading && (
                  <div className="flex items-center justify-center py-12">
                    <div className="text-center space-y-2">
                      <Loader className="w-8 h-8 text-[#60cdff] animate-spin mx-auto" />
                      <p className="text-gray-400">Loading submissions...</p>
                    </div>
                  </div>
                )}

                {/* Submissions Grid */}
                {!subsLoading && filteredSubmissions.length === 0 && (
                  <div className="text-center py-12 space-y-2">
                    <div className="text-4xl">🏜️</div>
                    <h3 className="text-white font-semibold">No submissions found</h3>
                    <p className="text-gray-500 text-sm">Try adjusting your search or filters</p>
                  </div>
                )}

                {!subsLoading && filteredSubmissions.length > 0 && (
                  <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                    {filteredSubmissions.map((sub) => (
                      <div
                        key={sub.id}
                        onClick={() => {
                          if (sub.isNsfw && sfwMode) {
                            alert(`This submission is NSFW. Disable SFW mode in settings to view it.`);
                          } else {
                            setSelectedSub(sub.id);
                          }
                        }}
                        className="bg-[#282828]/50 hover:bg-[#323232]/80 border border-white/5 hover:border-white/15 p-3 rounded-lg flex flex-col gap-2 cursor-pointer transition-all group"
                      >
                        <div className="aspect-square w-full rounded-md bg-gradient-to-br from-gray-700 to-gray-900 flex items-center justify-center text-xs relative overflow-hidden">
                          {sub.imageUrl ? (
                            <img
                              src={sub.imageUrl}
                              alt={sub.title}
                              className="w-full h-full object-cover group-hover:scale-105 transition"
                            />
                          ) : (
                            <span className="text-gray-400">No image</span>
                          )}

                          {sub.isNsfw && sfwMode && (
                            <div className="absolute inset-0 bg-black/95 flex flex-col items-center justify-center text-center">
                              <span className="text-lg">🔞</span>
                              <span className="text-xs text-red-400 font-bold mt-1">NSFW</span>
                            </div>
                          )}
                        </div>

                        <div>
                          <p className="text-xs font-semibold text-white truncate group-hover:text-[#60cdff]">
                            {sub.title}
                          </p>
                          <p className="text-xs text-[#60cdff]">@{sub.author}</p>

                          <div className="flex gap-2 mt-2 pt-2 border-t border-white/5 text-xs text-gray-400">
                            <span className="flex items-center gap-1">
                              <Heart className="w-3 h-3 text-pink-500" /> {sub.faves}
                            </span>
                            <span className="flex items-center gap-1">
                              <MessageSquare className="w-3 h-3" /> {sub.commentsCount}
                            </span>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                )}

                {/* Pagination */}
                {!subsLoading && filteredSubmissions.length > 0 && (
                  <div className="flex items-center justify-center gap-2 pt-6 border-t border-white/5">
                    <button
                      onClick={() => setCurrentPage(Math.max(1, currentPage - 1))}
                      disabled={currentPage === 1}
                      className="px-3 py-1 rounded bg-white/5 hover:bg-white/10 disabled:opacity-50 text-sm"
                    >
                      ← Previous
                    </button>
                    <span className="text-sm text-gray-400">Page {currentPage}</span>
                    <button
                      onClick={() => setCurrentPage(currentPage + 1)}
                      className="px-3 py-1 rounded bg-white/5 hover:bg-white/10 text-sm"
                    >
                      Next →
                    </button>
                  </div>
                )}
              </div>
            )}

            {/* Notifications Tab */}
            {activeTab === 'notifications' && (
              <div className="bg-[#121212]/95 rounded-2xl border border-white/5 shadow-2xl p-6">
                <div className="flex items-center justify-between mb-4">
                  <h2 className="text-lg font-bold text-white">Notifications</h2>
                  <button
                    onClick={refreshNotifications}
                    className="p-2 hover:bg-white/10 rounded transition"
                  >
                    <RefreshCw className="w-4 h-4" />
                  </button>
                </div>

                {notifications.length === 0 ? (
                  <div className="text-center py-12 text-gray-500">
                    No notifications
                  </div>
                ) : (
                  <div className="space-y-2">
                    {notifications.map(notif => (
                      <div
                        key={notif.id}
                        className="bg-[#2a2a2a]/60 border border-white/5 rounded-lg p-3 flex items-start gap-3 hover:bg-[#323232]/80 transition"
                      >
                        <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-blue-500 to-cyan-500 flex items-center justify-center text-xs font-bold text-white shrink-0">
                          {notif.author.substring(0, 1).toUpperCase()}
                        </div>
                        <div className="flex-1 min-w-0">
                          <p className="text-sm text-white">
                            <span className="font-semibold text-[#60cdff]">@{notif.author}</span> {notif.title}
                          </p>
                          <p className="text-xs text-gray-400 mt-1">{notif.datetime}</p>
                        </div>
                        <span className="text-xs bg-[#0078d4]/20 text-[#60cdff] px-2 py-1 rounded whitespace-nowrap">
                          {notif.type}
                        </span>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}

            {/* Settings Tab */}
            {activeTab === 'settings' && (
              <div className="bg-[#121212]/95 rounded-2xl border border-white/5 shadow-2xl p-6 space-y-6">
                <div className="space-y-4">
                  <h2 className="text-lg font-bold text-white">Settings</h2>

                  <div className="space-y-3">
                    <label className="flex items-center gap-3 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={sfwMode}
                        onChange={(e) => setSfwMode(e.target.checked)}
                        className="w-4 h-4 rounded border-white/20 text-[#0078d4]"
                      />
                      <div>
                        <p className="text-white font-medium">SFW Filter</p>
                        <p className="text-xs text-gray-400">Hide NSFW content (18+)</p>
                      </div>
                    </label>
                  </div>
                </div>

                <div className="border-t border-white/5 pt-4">
                  <h3 className="text-sm font-semibold text-white mb-3">Account Info</h3>
                  <div className="space-y-2 text-sm">
                    <div className="flex justify-between">
                      <span className="text-gray-400">Username:</span>
                      <span className="text-white font-mono">@{session.username}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-400">Status:</span>
                      <span className="text-emerald-400">Logged In</span>
                    </div>
                  </div>
                </div>
              </div>
            )}

            {/* Submission Details Modal */}
            {selectedSub && (
              <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4 z-50">
                <div className="bg-[#1a1a1a] rounded-xl border border-white/10 max-w-2xl w-full max-h-[90vh] overflow-y-auto shadow-2xl">
                  {/* Header */}
                  <div className="sticky top-0 bg-[#1a1a1a] p-4 border-b border-white/5 flex items-center justify-between">
                    <h2 className="text-lg font-bold text-white truncate">
                      {selectedSubmission?.title || 'Loading...'}
                    </h2>
                    <button
                      onClick={() => setSelectedSub(null)}
                      className="p-1 hover:bg-white/10 rounded transition"
                    >
                      <X className="w-5 h-5" />
                    </button>
                  </div>

                  {/* Content */}
                  <div className="p-6 space-y-6">
                    {subLoading ? (
                      <div className="flex items-center justify-center py-12">
                        <Loader className="w-6 h-6 animate-spin text-[#60cdff]" />
                      </div>
                    ) : selectedSubmission ? (
                      <>
                        {/* Image */}
                        {selectedSubmission.imageUrl && (
                          <div className="w-full rounded-lg overflow-hidden bg-gray-900">
                            <img
                              src={selectedSubmission.imageUrl}
                              alt={selectedSubmission.title}
                              className="w-full h-auto"
                            />
                          </div>
                        )}

                        {/* Info */}
                        <div className="space-y-2">
                          <h1 className="text-2xl font-bold text-white">{selectedSubmission.title}</h1>
                          <p className="text-[#60cdff] font-medium">By @{selectedSubmission.author}</p>
                          <p className="text-sm text-gray-400 flex items-center gap-1">
                            <Clock className="w-4 h-4" /> {selectedSubmission.date}
                          </p>
                        </div>

                        {/* Stats */}
                        <div className="flex gap-6 py-3 border-y border-white/5">
                          <div>
                            <p className="text-2xl font-bold text-white">{selectedSubmission.views}</p>
                            <p className="text-xs text-gray-400">Views</p>
                          </div>
                          <div>
                            <p className="text-2xl font-bold text-pink-500">{selectedSubmission.faves}</p>
                            <p className="text-xs text-gray-400">Favorites</p>
                          </div>
                          <div>
                            <p className="text-2xl font-bold text-blue-400">{selectedSubmission.commentsCount}</p>
                            <p className="text-xs text-gray-400">Comments</p>
                          </div>
                        </div>

                        {/* Description */}
                        <div>
                          <h3 className="font-semibold text-white mb-2">Description</h3>
                          <p className="text-sm text-gray-300">{selectedSubmission.description}</p>
                        </div>

                        {/* Tags */}
                        {selectedSubmission.tags.length > 0 && (
                          <div>
                            <h3 className="font-semibold text-white mb-2">Tags</h3>
                            <div className="flex flex-wrap gap-2">
                              {selectedSubmission.tags.map(tag => (
                                <span
                                  key={tag}
                                  className="bg-white/5 text-white px-2 py-1 rounded text-xs border border-white/10"
                                >
                                  #{tag}
                                </span>
                              ))}
                            </div>
                          </div>
                        )}

                        {/* Comments */}
                        <div className="border-t border-white/5 pt-6">
                          <h3 className="font-semibold text-white mb-4 flex items-center gap-2">
                            <MessageSquare className="w-4 h-4" />
                            Comments ({subComments.length})
                          </h3>

                          {commentsLoading ? (
                            <div className="flex items-center justify-center py-4">
                              <Loader className="w-4 h-4 animate-spin text-gray-400" />
                            </div>
                          ) : subComments.length === 0 ? (
                            <p className="text-gray-500 text-sm">No comments yet</p>
                          ) : (
                            <div className="space-y-3">
                              {subComments.map(comment => (
                                <div key={comment.id} className="bg-[#2a2a2a]/50 p-3 rounded border border-white/5">
                                  <div className="flex items-center gap-2 mb-1">
                                    <p className="font-medium text-white text-sm">@{comment.author}</p>
                                    <p className="text-xs text-gray-500">{comment.time}</p>
                                  </div>
                                  <p className="text-sm text-gray-300">{comment.text}</p>
                                </div>
                              ))}
                            </div>
                          )}
                        </div>
                      </>
                    ) : (
                      <p className="text-gray-500">Failed to load submission</p>
                    )}
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
