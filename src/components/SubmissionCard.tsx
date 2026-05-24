import React from 'react';
import {View, Text, Image, TouchableOpacity, StyleSheet} from 'react-native';
import {Submission} from '../types';
import {colors, font, spacing} from '../utils/theme';

interface Props {
  submission: Submission;
  sfwMode: boolean;
  onPress: (submission: Submission) => void;
  compact?: boolean;
}

export default function SubmissionCard({submission, sfwMode, onPress, compact}: Props) {
  const blocked = submission.isNsfw && sfwMode;

  const handlePress = () => {
    if (blocked) return;
    onPress(submission);
  };

  return (
    <TouchableOpacity
      onPress={handlePress}
      activeOpacity={blocked ? 1 : 0.7}
      style={[styles.card, compact && styles.cardCompact]}
    >
      <View style={[styles.imageContainer, compact && styles.imageContainerCompact]}>
        {submission.imageUrl ? (
          <Image
            source={{uri: submission.imageUrl}}
            style={styles.image}
            resizeMode="cover"
          />
        ) : (
          <View style={styles.noImage}>
            <Text style={styles.noImageText}>No image</Text>
          </View>
        )}
        {blocked && (
          <View style={styles.nsfwOverlay}>
            <Text style={styles.nsfwIcon}>🔞</Text>
            <Text style={styles.nsfwLabel}>NSFW</Text>
          </View>
        )}
      </View>
      <View style={styles.info}>
        <Text style={styles.title} numberOfLines={1}>
          {submission.title}
        </Text>
        <Text style={styles.author}>@{submission.author}</Text>
        <View style={styles.stats}>
          <Text style={styles.stat}>♥ {submission.faves}</Text>
          <Text style={styles.stat}>💬 {submission.commentsCount}</Text>
        </View>
      </View>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: `${colors.bgCardHover}80`,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: colors.border,
    overflow: 'hidden',
  },
  cardCompact: {},
  imageContainer: {
    aspectRatio: 1,
    backgroundColor: '#1f2937',
    position: 'relative',
  },
  imageContainerCompact: {},
  image: {
    width: '100%',
    height: '100%',
  },
  noImage: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  noImageText: {
    color: colors.textMuted,
    fontSize: font.sm,
  },
  nsfwOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.95)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  nsfwIcon: {
    fontSize: 24,
  },
  nsfwLabel: {
    color: colors.danger,
    fontWeight: 'bold',
    fontSize: font.sm,
    marginTop: 4,
  },
  info: {
    padding: spacing.sm,
  },
  title: {
    color: colors.text,
    fontWeight: '600',
    fontSize: font.sm,
  },
  author: {
    color: colors.accentLight,
    fontSize: font.sm,
    marginTop: 2,
  },
  stats: {
    flexDirection: 'row',
    gap: spacing.sm,
    marginTop: spacing.sm,
    paddingTop: spacing.xs,
    borderTopWidth: 1,
    borderTopColor: colors.border,
  },
  stat: {
    color: colors.textDim,
    fontSize: font.sm,
  },
});
