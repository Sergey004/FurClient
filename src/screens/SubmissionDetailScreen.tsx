import React, {useEffect, useState} from 'react';
import {
  View,
  Text,
  Image,
  ScrollView,
  StyleSheet,
  TouchableOpacity,
  Dimensions,
} from 'react-native';
import {Submission, Comment, FAUser} from '../types';
import {FAClient} from '../lib/faClient';
import CommentItem from '../components/CommentItem';
import LoadingIndicator from '../components/LoadingIndicator';
import ErrorView from '../components/ErrorView';
import {colors, font, spacing} from '../utils/theme';

interface Props {
  client: FAClient;
  submission: Submission;
  onBack: () => void;
  onUserPress: (username: string) => void;
}

export default function SubmissionDetailScreen({client, submission, onBack, onUserPress}: Props) {
  const [details, setDetails] = useState<Submission | null>(null);
  const [comments, setComments] = useState<Comment[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const load = async () => {
      try {
        const [sub, cmts] = await Promise.all([
          client.getSubmission(submission.id),
          client.getComments(submission.id),
        ]);
        setDetails(sub);
        setComments(cmts);
      } catch (e: any) {
        setError(e.message);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, [submission.id, client]);

  if (loading) {
    return <LoadingIndicator message="Loading submission..." />;
  }

  const data = details || submission;

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity onPress={onBack} style={styles.backButton}>
          <Text style={styles.backText}>← Back</Text>
        </TouchableOpacity>
        <Text style={styles.headerTitle} numberOfLines={1}>
          {data.title}
        </Text>
      </View>

      <ScrollView style={styles.content}>
        {error && <ErrorView message={error} />}

        {data.imageUrl && (
          <Image
            source={{uri: data.imageUrl}}
            style={styles.image}
            resizeMode="contain"
          />
        )}

        <View style={styles.infoSection}>
          <Text style={styles.title}>{data.title}</Text>
          <TouchableOpacity onPress={() => onUserPress(data.author)}>
            <Text style={styles.author}>By @{data.author}</Text>
          </TouchableOpacity>
          <Text style={styles.date}>{data.date}</Text>
        </View>

        <View style={styles.statsRow}>
          <View style={styles.stat}>
            <Text style={styles.statValue}>{data.views}</Text>
            <Text style={styles.statLabel}>Views</Text>
          </View>
          <View style={styles.stat}>
            <Text style={[styles.statValue, {color: colors.pink}]}>
              {data.faves}
            </Text>
            <Text style={styles.statLabel}>Favorites</Text>
          </View>
          <View style={styles.stat}>
            <Text style={[styles.statValue, {color: colors.blue}]}>
              {data.commentsCount}
            </Text>
            <Text style={styles.statLabel}>Comments</Text>
          </View>
        </View>

        {data.description ? (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Description</Text>
            <Text style={styles.description}>{data.description}</Text>
          </View>
        ) : null}

        {data.tags.length > 0 && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Tags</Text>
            <View style={styles.tags}>
              {data.tags.map(tag => (
                <View key={tag} style={styles.tag}>
                  <Text style={styles.tagText}>#{tag}</Text>
                </View>
              ))}
            </View>
          </View>
        )}

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>
            Comments ({comments.length})
          </Text>
          {comments.length === 0 ? (
            <Text style={styles.noComments}>No comments yet</Text>
          ) : (
            <View style={styles.commentsList}>
              {comments.map(c => (
                <CommentItem key={c.id} comment={c} />
              ))}
            </View>
          )}
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.bg,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.lg,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
    backgroundColor: colors.bgCard,
  },
  backButton: {
    marginRight: spacing.md,
  },
  backText: {
    color: colors.accentLight,
    fontSize: font.lg,
  },
  headerTitle: {
    flex: 1,
    color: colors.text,
    fontSize: font.lg,
    fontWeight: 'bold',
  },
  content: {
    flex: 1,
  },
  image: {
    width: Dimensions.get('window').width,
    height: Dimensions.get('window').width * 0.75,
    backgroundColor: '#1f2937',
  },
  infoSection: {
    padding: spacing.lg,
    gap: spacing.xs,
  },
  title: {
    color: colors.text,
    fontSize: font.xxl,
    fontWeight: 'bold',
  },
  author: {
    color: colors.accentLight,
    fontSize: font.lg,
    fontWeight: '500',
  },
  date: {
    color: colors.textMuted,
    fontSize: font.md,
  },
  statsRow: {
    flexDirection: 'row',
    gap: spacing.xxl,
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.lg,
    borderTopWidth: 1,
    borderBottomWidth: 1,
    borderColor: colors.border,
  },
  stat: {},
  statValue: {
    fontSize: font.xxl,
    fontWeight: 'bold',
    color: colors.text,
  },
  statLabel: {
    fontSize: font.sm,
    color: colors.textMuted,
  },
  section: {
    padding: spacing.lg,
    gap: spacing.sm,
  },
  sectionTitle: {
    color: colors.text,
    fontWeight: '600',
    fontSize: font.lg,
  },
  description: {
    color: colors.textDim,
    fontSize: font.md,
    lineHeight: 22,
  },
  tags: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
  },
  tag: {
    backgroundColor: `${colors.bgInput}80`,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
    borderRadius: 4,
    borderWidth: 1,
    borderColor: colors.border,
  },
  tagText: {
    color: colors.text,
    fontSize: font.sm,
  },
  noComments: {
    color: colors.textMuted,
    fontSize: font.md,
  },
  commentsList: {
    gap: spacing.sm,
  },
});
