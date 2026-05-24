import React from 'react';
import {View, Text, Switch, TouchableOpacity, StyleSheet} from 'react-native';
import {UserSession} from '../types';
import {colors, font, spacing} from '../utils/theme';

interface Props {
  sfwMode: boolean;
  onToggleSfw: (value: boolean) => void;
  session: UserSession;
  onLogout: () => void;
}

export default function SettingsScreen({sfwMode, onToggleSfw, session, onLogout}: Props) {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>Settings</Text>

      <View style={styles.section}>
        <View style={styles.row}>
          <View style={styles.rowText}>
            <Text style={styles.rowTitle}>SFW Filter</Text>
            <Text style={styles.rowSubtitle}>Hide NSFW content (18+)</Text>
          </View>
          <Switch
            value={sfwMode}
            onValueChange={onToggleSfw}
            trackColor={{false: colors.bgInput, true: `${colors.accent}66`}}
            thumbColor={sfwMode ? colors.accent : colors.textDim}
          />
        </View>
      </View>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Account Info</Text>
        <View style={styles.infoRow}>
          <Text style={styles.infoLabel}>Username:</Text>
          <Text style={styles.infoValue}>@{session.username}</Text>
        </View>
        <View style={styles.infoRow}>
          <Text style={styles.infoLabel}>Status:</Text>
          <Text style={[styles.infoValue, {color: colors.success}]}>
            Logged In
          </Text>
        </View>
      </View>

      <TouchableOpacity style={styles.logoutButton} onPress={onLogout}>
        <Text style={styles.logoutText}>Logout</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    gap: spacing.xxl,
  },
  title: {
    color: colors.text,
    fontSize: font.xl,
    fontWeight: 'bold',
  },
  section: {
    gap: spacing.md,
  },
  sectionTitle: {
    color: colors.textDim,
    fontWeight: '600',
    fontSize: font.md,
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: spacing.md,
  },
  rowText: {},
  rowTitle: {
    color: colors.text,
    fontSize: font.md,
    fontWeight: '500',
  },
  rowSubtitle: {
    color: colors.textMuted,
    fontSize: font.sm,
  },
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: spacing.sm,
  },
  infoLabel: {
    color: colors.textMuted,
    fontSize: font.md,
  },
  infoValue: {
    color: colors.text,
    fontSize: font.md,
  },
  logoutButton: {
    backgroundColor: `${colors.danger}33`,
    paddingVertical: spacing.md,
    borderRadius: 8,
    alignItems: 'center',
  },
  logoutText: {
    color: colors.danger,
    fontWeight: '600',
    fontSize: font.lg,
  },
});
