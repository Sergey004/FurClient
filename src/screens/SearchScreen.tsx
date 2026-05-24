import React, {useState} from 'react';
import {
  View,
  Text,
  TextInput,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
} from 'react-native';
import {Submission} from '../types';
import {FAClient} from '../lib/faClient';
import SubmissionCard from '../components/SubmissionCard';
import ErrorView from '../components/ErrorView';
import {colors, font, spacing} from '../utils/theme';

interface Props {
  client: FAClient;
  sfwMode: boolean;
  onSubmissionPress: (submission: Submission) => void;
}

export default function SearchScreen({client, sfwMode, onSubmissionPress}: Props) {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<Submission[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [searched, setSearched] = useState(false);

  const handleSearch = async () => {
    if (!query.trim()) return;
    setLoading(true);
    setError(null);
    setSearched(true);
    try {
      const data = await client.search(query.trim());
      setResults(data);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <View style={styles.container}>
      <View style={styles.searchBar}>
        <TextInput
          style={styles.input}
          value={query}
          onChangeText={setQuery}
          placeholder="Search by title, author, or tags..."
          placeholderTextColor={colors.textMuted}
          onSubmitEditing={handleSearch}
          returnKeyType="search"
        />
      </View>

      {error && <ErrorView message={error} />}

      {loading ? (
        <View style={styles.center}>
          <ActivityIndicator size="large" color={colors.accentLight} />
        </View>
      ) : searched && results.length === 0 ? (
        <View style={styles.center}>
          <Text style={styles.emptyIcon}>🔍</Text>
          <Text style={styles.emptyTitle}>No results found</Text>
          <Text style={styles.emptySubtitle}>
            Try a different search term
          </Text>
        </View>
      ) : !searched ? (
        <View style={styles.center}>
          <Text style={styles.emptyIcon}>🔍</Text>
          <Text style={styles.emptyTitle}>Search FA Nexus</Text>
          <Text style={styles.emptySubtitle}>
            Find submissions by title, author, or tags
          </Text>
        </View>
      ) : (
        <FlatList
          data={results}
          renderItem={({item}) => (
            <View style={styles.cardWrapper}>
              <SubmissionCard
                submission={item}
                sfwMode={sfwMode}
                onPress={onSubmissionPress}
                compact
              />
            </View>
          )}
          keyExtractor={item => item.id}
          numColumns={2}
          columnWrapperStyle={styles.columnWrapper}
          contentContainerStyle={styles.list}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  searchBar: {
    backgroundColor: `${colors.bgInput}80`,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: 8,
    paddingHorizontal: spacing.md,
    marginBottom: spacing.lg,
  },
  input: {
    color: colors.text,
    fontSize: font.md,
    paddingVertical: spacing.sm,
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
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
});
