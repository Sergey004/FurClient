import React from 'react';
import {View, Text, StyleSheet} from 'react-native';
import {colors, font, spacing} from '../utils/theme';

interface Props {
  message: string;
}

export default function ErrorView({message}: Props) {
  return (
    <View style={styles.container}>
      <Text style={styles.icon}>⚠</Text>
      <Text style={styles.text}>{message}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    padding: spacing.lg,
    backgroundColor: colors.dangerBg,
    borderWidth: 1,
    borderColor: 'rgba(239,68,68,0.2)',
    borderRadius: 8,
  },
  icon: {
    fontSize: 20,
  },
  text: {
    color: colors.danger,
    fontSize: font.md,
    flex: 1,
  },
});
