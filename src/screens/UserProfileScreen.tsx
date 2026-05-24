import React, {useEffect, useState} from 'react';
import {View, Text, Image, ScrollView, StyleSheet, TouchableOpacity} from 'react-native';
import {FAUser} from '../types';
import {FAClient} from '../lib/faClient';
import LoadingIndicator from '../components/LoadingIndicator';
import ErrorView from '../components/ErrorView';
import {colors, font, spacing} from '../utils/theme';

interface Props {
  client: FAClient;
  username: string;
  onBack: () => void;
}

export default function UserProfileScreen({client, username, onBack}: Props) {
  const [user, setUser] = useState<FAUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const load = async () => {
      try {
        const data = await client.getUser(username);
        setUser(data);
      } catch (e: any) {
        setError(e.message);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, [username, client]);

  if (loading) {
    return <LoadingIndicator message="Loading profile..." />;
  }

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity onPress={onBack} style={styles.backButton}>
          <Text style={styles.backText}>← Back</Text>
        </TouchableOpacity>
        <Text style={styles.headerTitle}>@{username}</Text>
      </View>

      <ScrollView style={styles.content}>
        {error && <ErrorView message={error} />}

        {user && (
          <>
            {user.bannerUrl ? (
              <Image
                source={{uri: user.bannerUrl}}
                style={styles.banner}
                resizeMode="cover"
              />
            ) : (
              <View style={styles.bannerPlaceholder} />
            )}

            <View style={styles.profileSection}>
              {user.avatarUrl ? (
                <Image source={{uri: user.avatarUrl}} style={styles.avatar} />
              ) : (
                <View style={styles.avatarPlaceholder}>
                  <Text style={styles.avatarLetter}>
                    {user.displayName[0]?.toUpperCase()}
                  </Text>
                </View>
              )}

              <View style={styles.nameSection}>
                <Text style={styles.displayName}>{user.displayName}</Text>
                <Text style={styles.username}>@{user.username}</Text>
              </View>
            </View>

            <View style={styles.statsRow}>
              <StatItem label="Views" value={user.stats.views} />
              <StatItem label="Submissions" value={user.stats.submissions} />
              <StatItem label="Favorites" value={user.stats.favorites} />
              <StatItem label="Comments" value={user.stats.comments} />
            </View>

            {user.description ? (
              <View style={styles.section}>
                <Text style={styles.sectionTitle}>About</Text>
                <Text style={styles.description}>{user.description}</Text>
              </View>
            ) : null}
          </>
        )}
      </ScrollView>
    </View>
  );
}

function StatItem({label, value}: {label: string; value: number}) {
  return (
    <View style={styles.stat}>
      <Text style={styles.statValue}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
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
    color: colors.text,
    fontSize: font.lg,
    fontWeight: 'bold',
  },
  content: {
    flex: 1,
  },
  banner: {
    width: '100%',
    height: 150,
  },
  bannerPlaceholder: {
    width: '100%',
    height: 100,
    backgroundColor: '#1f2937',
  },
  profileSection: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    paddingHorizontal: spacing.lg,
    marginTop: -40,
    gap: spacing.md,
  },
  avatar: {
    width: 80,
    height: 80,
    borderRadius: 40,
    borderWidth: 3,
    borderColor: colors.bg,
  },
  avatarPlaceholder: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: colors.accent,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 3,
    borderColor: colors.bg,
  },
  avatarLetter: {
    color: colors.text,
    fontSize: 32,
    fontWeight: 'bold',
  },
  nameSection: {
    paddingBottom: spacing.xs,
  },
  displayName: {
    color: colors.text,
    fontSize: font.xxl,
    fontWeight: 'bold',
  },
  username: {
    color: colors.accentLight,
    fontSize: font.lg,
  },
  statsRow: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    paddingVertical: spacing.lg,
    paddingHorizontal: spacing.lg,
    borderBottomWidth: 1,
    borderColor: colors.border,
  },
  stat: {
    alignItems: 'center',
  },
  statValue: {
    color: colors.text,
    fontSize: font.xl,
    fontWeight: 'bold',
  },
  statLabel: {
    color: colors.textMuted,
    fontSize: font.sm,
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
});
