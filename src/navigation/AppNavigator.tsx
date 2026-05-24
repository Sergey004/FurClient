import React from 'react';
import {NavigationContainer} from '@react-navigation/native';
import {createNativeStackNavigator} from '@react-navigation/native-stack';
import {createBottomTabNavigator} from '@react-navigation/bottom-tabs';
import {Submission, UserSession} from '../types';
import {FAClient} from '../lib/faClient';

import GalleryScreen from '../screens/GalleryScreen';
import SubmissionDetailScreen from '../screens/SubmissionDetailScreen';
import UserProfileScreen from '../screens/UserProfileScreen';
import SearchScreen from '../screens/SearchScreen';
import NotificationsScreen from '../screens/NotificationsScreen';
import SettingsScreen from '../screens/SettingsScreen';

const Stack = createNativeStackNavigator();
const Tab = createBottomTabNavigator();

interface Props {
  client: FAClient;
  session: UserSession;
  sfwMode: boolean;
  onToggleSfw: (v: boolean) => void;
  onLogout: () => void;
}

function MainTabs({client, sfwMode, onToggleSfw, session, onLogout}: Props) {
  const [selectedSub, setSelectedSub] = React.useState<Submission | null>(null);
  const [profileUsername, setProfileUsername] = React.useState<string | null>(null);

  if (profileUsername) {
    return (
      <UserProfileScreen
        client={client}
        username={profileUsername}
        onBack={() => setProfileUsername(null)}
      />
    );
  }

  if (selectedSub) {
    return (
      <SubmissionDetailScreen
        client={client}
        submission={selectedSub}
        onBack={() => setSelectedSub(null)}
        onUserPress={username => {
          setSelectedSub(null);
          setProfileUsername(username);
        }}
      />
    );
  }

  return (
    <Tab.Navigator
      screenOptions={{
        tabBarStyle: {
          backgroundColor: '#1a1a1a',
          borderTopColor: 'rgba(255,255,255,0.1)',
          borderTopWidth: 1,
        },
        tabBarActiveTintColor: '#60cdff',
        tabBarInactiveTintColor: '#6b7280',
        headerShown: false,
      }}
    >
      <Tab.Screen
        name="Gallery"
        options={{tabBarLabel: 'Gallery', tabBarLabelStyle: {fontSize: 12}}}
      >
        {() => (
          <GalleryScreen
            client={client}
            sfwMode={sfwMode}
            onSubmissionPress={setSelectedSub}
          />
        )}
      </Tab.Screen>
      <Tab.Screen
        name="Search"
        options={{tabBarLabel: 'Search', tabBarLabelStyle: {fontSize: 12}}}
      >
        {() => (
          <SearchScreen
            client={client}
            sfwMode={sfwMode}
            onSubmissionPress={setSelectedSub}
          />
        )}
      </Tab.Screen>
      <Tab.Screen
        name="Notifications"
        options={{tabBarLabel: 'Alerts', tabBarLabelStyle: {fontSize: 12}}}
      >
        {() => <NotificationsScreen client={client} />}
      </Tab.Screen>
      <Tab.Screen
        name="Settings"
        options={{tabBarLabel: 'Settings', tabBarLabelStyle: {fontSize: 12}}}
      >
        {() => (
          <SettingsScreen
            sfwMode={sfwMode}
            onToggleSfw={onToggleSfw}
            session={session}
            onLogout={onLogout}
          />
        )}
      </Tab.Screen>
    </Tab.Navigator>
  );
}

export default function AppNavigator({client, session, sfwMode, onToggleSfw, onLogout}: Props) {
  return (
    <NavigationContainer>
      <MainTabs
        client={client}
        session={session}
        sfwMode={sfwMode}
        onToggleSfw={onToggleSfw}
        onLogout={onLogout}
      />
    </NavigationContainer>
  );
}
