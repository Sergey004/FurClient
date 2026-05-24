import React, {useState} from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  Alert,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import {colors, font, spacing} from '../utils/theme';
import {UserSession} from '../types';
import {fetchUserSession} from '../lib/faClient';

interface Props {
  onLogin: (session: UserSession) => void;
}

export default function LoginScreen({onLogin}: Props) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleLogin = async () => {
    if (!username.trim() || !password.trim()) return;

    setLoading(true);
    setError(null);

    try {
      const session = await fetchUserSession(username.trim(), password);
      if (session) {
        onLogin(session);
      } else {
        setError('Login failed. Check your credentials.');
      }
    } catch (e: any) {
      setError(e.message || 'Network error. Try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
    >
      <View style={styles.card}>
        <View style={styles.logo}>
          <View style={styles.logoIcon}>
            <Text style={styles.logoText}>FA</Text>
          </View>
          <Text style={styles.title}>FA Nexus</Text>
          <Text style={styles.subtitle}>Fur Affinity Client</Text>
        </View>

        <View style={styles.form}>
          <Text style={styles.label}>Username</Text>
          <TextInput
            style={styles.input}
            value={username}
            onChangeText={setUsername}
            placeholder="Enter your FA username"
            placeholderTextColor={colors.textMuted}
            autoCapitalize="none"
            autoCorrect={false}
            editable={!loading}
          />

          <Text style={styles.label}>Password</Text>
          <TextInput
            style={styles.input}
            value={password}
            onChangeText={setPassword}
            placeholder="Enter your password"
            placeholderTextColor={colors.textMuted}
            secureTextEntry
            editable={!loading}
          />

          {error && (
            <View style={styles.error}>
              <Text style={styles.errorText}>{error}</Text>
            </View>
          )}

          <TouchableOpacity
            style={[styles.button, loading && styles.buttonDisabled]}
            onPress={handleLogin}
            disabled={loading || !username.trim() || !password.trim()}
          >
            {loading ? (
              <ActivityIndicator color={colors.text} />
            ) : (
              <Text style={styles.buttonText}>Login</Text>
            )}
          </TouchableOpacity>
        </View>

        <Text style={styles.hint}>
          Your credentials are only used for this session
        </Text>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.bg,
    justifyContent: 'center',
    padding: spacing.xl,
  },
  card: {
    backgroundColor: colors.bgCard,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: 12,
    padding: spacing.xxl,
    maxWidth: 400,
    width: '100%',
    alignSelf: 'center',
  },
  logo: {
    alignItems: 'center',
    gap: spacing.sm,
    marginBottom: spacing.xxl,
  },
  logoIcon: {
    width: 48,
    height: 48,
    borderRadius: 8,
    backgroundColor: colors.accent,
    justifyContent: 'center',
    alignItems: 'center',
  },
  logoText: {
    color: colors.text,
    fontWeight: 'bold',
    fontSize: font.xl,
  },
  title: {
    color: colors.text,
    fontSize: font.title,
    fontWeight: 'bold',
  },
  subtitle: {
    color: colors.textMuted,
    fontSize: font.md,
  },
  form: {
    gap: spacing.md,
  },
  label: {
    color: colors.textDim,
    fontSize: font.md,
    fontWeight: '500',
  },
  input: {
    backgroundColor: colors.bgInput,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: 8,
    padding: spacing.md,
    color: colors.text,
    fontSize: font.md,
  },
  error: {
    backgroundColor: colors.dangerBg,
    borderWidth: 1,
    borderColor: 'rgba(239,68,68,0.2)',
    borderRadius: 8,
    padding: spacing.md,
  },
  errorText: {
    color: colors.danger,
    fontSize: font.md,
  },
  button: {
    backgroundColor: colors.accent,
    borderRadius: 8,
    padding: spacing.md,
    alignItems: 'center',
    marginTop: spacing.sm,
  },
  buttonDisabled: {
    opacity: 0.5,
  },
  buttonText: {
    color: colors.text,
    fontWeight: '600',
    fontSize: font.lg,
  },
  hint: {
    color: colors.textMuted,
    fontSize: font.sm,
    textAlign: 'center',
    marginTop: spacing.lg,
  },
});
