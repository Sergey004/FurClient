import React from 'react';
import {View, Text, ActivityIndicator, StyleSheet} from 'react-native';
import {colors, font} from '../utils/theme';

interface Props {
  message?: string;
}

export default function LoadingIndicator({message}: Props) {
  return (
    <View style={styles.container}>
      <ActivityIndicator size="large" color={colors.accentLight} />
      {message && <Text style={styles.text}>{message}</Text>}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 32,
    gap: 12,
  },
  text: {
    color: colors.textDim,
    fontSize: font.md,
  },
});
