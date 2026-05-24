import React, {useEffect, useState} from 'react';
import {View, StyleSheet, StatusBar, SafeAreaView} from 'react-native';
import {UserSession} from './types';
import {FAClient} from './lib/faClient';
import {loadSession, saveSession, clearSession} from './lib/faSession';
import {isElectron} from './lib/electronLogin';
import LoginScreen from './screens/LoginScreen';
import AppNavigator from './navigation/AppNavigator';
import LoadingIndicator from './components/LoadingIndicator';
import {colors} from './utils/theme';

export default function App() {
  const [session, setSession] = useState<UserSession | null>(null);
  const [sfwMode, setSfwMode] = useState(true);
  const [initializing, setInitializing] = useState(true);
  const [client] = useState(() => new FAClient(null));

  useEffect(() => {
    const init = async () => {
      const saved = await loadSession();
      if (saved) {
        client.setSession(saved);
        const valid = await client.verifySession();
        if (valid) {
          setSession(saved);
          if (isElectron() && saved.cookies) {
            window.electronAPI?.restoreSessionCookies(saved.cookies);
          }
        } else {
          await clearSession();
        }
      }
      setInitializing(false);
    };
    init();
  }, [client]);

  const handleLogin = async (userSession: UserSession) => {
    setSession(userSession);
    client.setSession(userSession);
    await saveSession(userSession);
  };

  const handleLogout = async () => {
    setSession(null);
    client.setSession(null);
    await clearSession();
  };

  if (initializing) {
    return (
      <View style={styles.container}>
        <LoadingIndicator />
      </View>
    );
  }

  if (!session) {
    return (
      <View style={styles.container}>
        <StatusBar barStyle="light-content" backgroundColor={colors.bg} />
        <LoginScreen onLogin={handleLogin} />
      </View>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="light-content" backgroundColor={colors.bg} />
      <AppNavigator
        client={client}
        session={session}
        sfwMode={sfwMode}
        onToggleSfw={setSfwMode}
        onLogout={handleLogout}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.bg,
    padding: 16,
  },
});
