import React from 'react';
import {View, Text, TouchableOpacity, StyleSheet} from 'react-native';
import {FANotification} from '../types';
import {colors, font, spacing} from '../utils/theme';

interface Props {
  notification: FANotification;
  onPress?: () => void;
}

export default function NotificationItem({notification, onPress}: Props) {
  return (
    <TouchableOpacity
      onPress={onPress}
      activeOpacity={0.7}
      style={styles.container}
    >
      <View style={styles.avatar}>
        <Text style={styles.avatarText}>
          {notification.author[0]?.toUpperCase()}
        </Text>
      </View>
      <View style={styles.content}>
        <Text style={styles.title} numberOfLines={2}>
          <Text style={styles.author}>@{notification.author}</Text>{' '}
          {notification.title}
        </Text>
        <Text style={styles.time}>{notification.datetime}</Text>
      </View>
      <View style={styles.badge}>
        <Text style={styles.badgeText}>{notification.type}</Text>
      </View>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: spacing.sm,
    padding: spacing.md,
    backgroundColor: `${colors.bgCardHover}80`,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: 8,
  },
  avatar: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: colors.accent,
    justifyContent: 'center',
    alignItems: 'center',
  },
  avatarText: {
    color: colors.text,
    fontWeight: 'bold',
    fontSize: font.sm,
  },
  content: {
    flex: 1,
  },
  title: {
    color: colors.text,
    fontSize: font.md,
    lineHeight: 20,
  },
  author: {
    color: colors.accentLight,
    fontWeight: '600',
  },
  time: {
    color: colors.textMuted,
    fontSize: font.sm,
    marginTop: spacing.xs,
  },
  badge: {
    backgroundColor: `${colors.accent}33`,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
    borderRadius: 4,
  },
  badgeText: {
    color: colors.accentLight,
    fontSize: font.sm,
  },
});
