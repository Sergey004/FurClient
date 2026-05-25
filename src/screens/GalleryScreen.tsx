import React, {useEffect, useState, useCallback} from 'react';
import {
  View,
  Text,
  FlatList,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  RefreshControl,
  Dimensions,
} from 'react-native';
import {Submission} from '../types';
import {FAClient} from '../lib/faClient';
import SubmissionCard from '../components/SubmissionCard';
import LoadingIndicator from '../components/LoadingIndicator';
import ErrorView from '../components/ErrorView';
import {colors, font, spacing} from '../utils/theme';

interface Props {
  client: FAClient;
  sfwMode: boolean;
  onSubmissionPress: (submission: Submission) => void;
}

const CATEGORIES = ['All', 'Digital', 'Traditional', 'Writing'] as const;
const NUM_COLUMNS = 2;

export default function GalleryScreen({client, sfwMode, onSubmissionPress}: Props) {
  const [submissions, setSubmissions] = useState<Submission[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  const [category, setCategory] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState('');

  const fetchData = useCallback(async (p: number, cat: string) => {
    try {
      setError(null);
      const data = await client.getSubmissions(p, cat);
      setSubmissions(prev => p === 1 ? data : [...prev, ...data]);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [client]);

  useEffect(() => {
    setLoading(true);
    fetchData(page, category);
  }, [page, category, fetchData]);

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    fetchData(page, category);
  }, [fetchData, page, category]);

  const handleSearch = async () => {
    if (!searchQuery.trim()) return;
    setLoading(true);
    try {
      setError(null);
      const results = await client.search(searchQuery.trim());
      setSubmissions(results);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  const filtered = searchQuery.trim()
    ? submissions.filter(s =>
        s.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        s.author.toLowerCase().includes(searchQuery.toLowerCase())
      )
    : submissions;

  const renderItem = ({item}: {item: Submission}) => (
    <View style={styles.cardWrapper}>
      <SubmissionCard
        submission={item}
        sfwMode={sfwMode}
        onPress={onSubmissionPress}
        compact
      />
    </View>
  );

  if (loading && !refreshing) {
    return <LoadingIndicator message="Loading submissions..." />;
  }

  return (
    <View style={styles.container}>
      {error && <ErrorView message={error} />}

      <View style={styles.searchBar}>
        <TextInput
          style={styles.searchInput}
          value={searchQuery}
          onChangeText={setSearchQuery}
          placeholder="Search submissions..."
          placeholderTextColor={colors.textMuted}
          onSubmitEditing={handleSearch}
          returnKeyType="search"
        />
      </View>

      <View style={styles.categories}>
        {CATEGORIES.map(cat => (
          <TouchableOpacity
            key={cat}
            style={[
              styles.categoryButton,
              category === cat.toLowerCase() && styles.categoryActive,
            ]}
            onPress={() => {
              setCategory(cat.toLowerCase());
              setPage(1);
            }}
          >
            <Text
              style={[
                styles.categoryText,
                category === cat.toLowerCase() && styles.categoryTextActive,
              ]}
            >
              {cat}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      <FlatList
        data={filtered}
        renderItem={renderItem}
        keyExtractor={item => item.id}
        numColumns={NUM_COLUMNS}
        contentContainerStyle={styles.list}
        columnWrapperStyle={styles.columnWrapper}
        refreshControl={
          <RefreshControl
            refreshing={refreshing}
            onRefresh={onRefresh}
            tintColor={colors.accentLight}
          />
        }
        ListEmptyComponent={
          <View style={styles.empty}>
            <Text style={styles.emptyIcon}>🏜️</Text>
            <Text style={styles.emptyTitle}>No submissions found</Text>
            <Text style={styles.emptySubtitle}>
              Try adjusting your search or filters
            </Text>
          </View>
        }
        onEndReached={() => {
          setPage(p => p + 1);
        }}
        onEndReachedThreshold={0.5}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  searchBar: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: `${colors.bgInput}80`,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: 8,
    paddingHorizontal: spacing.md,
    marginBottom: spacing.sm,
  },
  searchInput: {
    flex: 1,
    color: colors.text,
    fontSize: font.md,
    paddingVertical: spacing.sm,
  },
  categories: {
    flexDirection: 'row',
    gap: spacing.sm,
    marginBottom: spacing.md,
  },
  categoryButton: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
    borderRadius: 6,
    backgroundColor: `${colors.bgInput}80`,
  },
  categoryActive: {
    backgroundColor: `${colors.accent}33`,
    borderWidth: 1,
    borderColor: colors.borderLight,
  },
  categoryText: {
    color: colors.textDim,
    fontSize: font.md,
  },
  categoryTextActive: {
    color: colors.accentLight,
  },
  list: {
    paddingBottom: spacing.xxl,
  },
  columnWrapper: {
    gap: spacing.sm,
  },
  cardWrapper: {
    flex: 1,
    marginBottom: spacing.sm,
  },
  empty: {
    alignItems: 'center',
    paddingVertical: 48,
    gap: spacing.sm,
  },
  emptyIcon: {
    fontSize: 36,
  },
  emptyTitle: {
    color: colors.text,
    fontWeight: '600',
    fontSize: font.lg,
  },
  emptySubtitle: {
    color: colors.textMuted,
    fontSize: font.md,
  },
});
