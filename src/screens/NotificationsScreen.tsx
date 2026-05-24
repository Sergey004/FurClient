import React, {useEffect, useState, useCallback} from 'react';
import {View, Text, FlatList, TouchableOpacity, StyleSheet, RefreshControl} from 'react-native';
import {FANotification} from '../types';
import {FAClient} from '../lib/faClient';
import NotificationItem from '../components/NotificationItem';
import LoadingIndicator from '../components/LoadingIndicator';
import ErrorView from '../components/ErrorView';
import {colors, font, spacing} from '../utils/theme';

interface Props {
  client: FAClient;
}

export default function NotificationsScreen({client}: Props) {
  const [notifications, setNotifications] = useState<FANotification[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchData = useCallback(async () => {
    try {
      setError(null);
      const data = await client.getNotifications();
      setNotifications(data);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [client]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    fetchData();
  }, [fetchData]);

  if (loading && !refreshing) {
    return <LoadingIndicator message="Loading notifications..." />;
  }

  return (
    <View style={styles.container}>
      <View style={styles.headerRow}>
        <Text style={styles.headerTitle}>Notifications</Text>
        <TouchableOpacity onPress={onRefresh} style={styles.refreshButton}>
          <Text style={styles.refreshText}>↻</Text>
        </TouchableOpacity>
      </View>

      {error && <ErrorView message={error} />}

      <FlatList
        data={notifications}
        renderItem={({item}) => <NotificationItem notification={item} />}
        keyExtractor={item => item.id}
        contentContainerStyle={styles.list}
        ItemSeparatorComponent={() => <View style={styles.separator} />}
        refreshControl={
          <RefreshControl
            refreshing={refreshing}
            onRefresh={onRefresh}
            tintColor={colors.accentLight}
          />
        }
        ListEmptyComponent={
          <View style={styles.empty}>
            <Text style={styles.emptyText}>No notifications</Text>
          </View>
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: spacing.md,
  },
  headerTitle: {
    color: colors.text,
    fontSize: font.xl,
    fontWeight: 'bold',
  },
  refreshButton: {
    padding: spacing.sm,
  },
  refreshText: {
    color: colors.accentLight,
    fontSize: font.xxl,
  },
  list: {
    paddingBottom: spacing.xxl,
  },
  separator: {
    height: spacing.sm,
  },
  empty: {
    alignItems: 'center',
    paddingVertical: 48,
  },
  emptyText: {
    color: colors.textMuted,
    fontSize: font.md,
  },
});
