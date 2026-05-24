import React from 'react';
import {View} from 'react-native';

export function enableScreens() {}

export function screensEnabled() {
  return false;
}

export function Screen({children, ...props}: any) {
  return React.createElement(View, props, children);
}

export function ScreenContainer({children}: any) {
  return React.createElement(View, {style: {flex: 1}}, children);
}

export function NativeScreen({children}: any) {
  return React.createElement(View, {style: {flex: 1}}, children);
}

export function NativeScreenContainer({children}: any) {
  return React.createElement(View, {style: {flex: 1}}, children);
}

export default {
  enableScreens,
  screensEnabled,
  Screen,
  ScreenContainer,
  NativeScreen,
  NativeScreenContainer,
};
