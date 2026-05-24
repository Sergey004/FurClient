import React from 'react';
import {View, Text, Image, StyleSheet} from 'react-native';
import {Comment} from '../types';
import {colors, font, spacing} from '../utils/theme';

interface Props {
  comment: Comment;
}

export default function CommentItem({comment}: Props) {
  return (
    <View style={styles.container}>
      <View style={styles.header}>
        {comment.avatarUrl ? (
          <Image source={{uri: comment.avatarUrl}} style={styles.avatar} />
        ) : (
          <View style={styles.avatarPlaceholder}>
            <Text style={styles.avatarLetter}>
              {comment.author[0]?.toUpperCase()}
            </Text>
          </View>
        )}
        <View style={styles.headerText}>
          <Text style={styles.author}>@{comment.author}</Text>
          <Text style={styles.time}>{comment.time}</Text>
        </View>
      </View>
      <Text style={styles.text}>{comment.text}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: `${colors.bgInput}80`,
    padding: spacing.md,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: colors.border,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    marginBottom: spacing.xs,
  },
  avatar: {
    width: 24,
    height: 24,
    borderRadius: 12,
  },
  avatarPlaceholder: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: colors.accent,
    justifyContent: 'center',
    alignItems: 'center',
  },
  avatarLetter: {
    color: colors.text,
    fontSize: font.sm,
    fontWeight: 'bold',
  },
  headerText: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  author: {
    color: colors.text,
    fontWeight: '600',
    fontSize: font.md,
  },
  time: {
    color: colors.textMuted,
    fontSize: font.sm,
  },
  text: {
    color: colors.textDim,
    fontSize: font.md,
    lineHeight: 20,
  },
});
