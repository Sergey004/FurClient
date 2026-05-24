import React from 'react';
import {Dimensions, View} from 'react-native';

const initialMetrics = {
  frame: {x: 0, y: 0, width: Dimensions.get('window').width, height: Dimensions.get('window').height},
  insets: {top: 0, bottom: 0, left: 0, right: 0},
};

export const initialWindowMetrics = initialMetrics;

export const SafeAreaInsetsContext = React.createContext(initialMetrics.insets);

export const SafeAreaFrameContext = React.createContext(initialMetrics.frame);

export function SafeAreaProvider({children, initialMetrics: _im, ...rest}: any) {
  return React.createElement(
    SafeAreaInsetsContext.Provider,
    {value: initialMetrics.insets},
    React.createElement(
      SafeAreaFrameContext.Provider,
      {value: initialMetrics.frame},
      typeof children === 'function'
        ? children(initialMetrics)
        : React.createElement(View, {style: {flex: 1}}, children),
    ),
  );
}

export function useSafeAreaInsets() {
  return {top: 0, bottom: 0, left: 0, right: 0};
}

export function useSafeAreaFrame() {
  return initialMetrics.frame;
}

export function SafeAreaView({children, style, ...props}: any) {
  return React.createElement(View, {...props, style: [{flex: 1}, style].flat()}, children);
}

type Metrics = typeof initialMetrics;

export function withSafeAreaInsets(WrappedComponent: any) {
  return function WithSafeAreaInsets(props: any) {
    return React.createElement(WrappedComponent, {...props, insets: initialMetrics.insets});
  };
}

export function withSafeAreaFrame(WrappedComponent: any) {
  return function WithSafeAreaFrame(props: any) {
    return React.createElement(WrappedComponent, {...props, frame: initialMetrics.frame});
  };
}

export default SafeAreaView;
