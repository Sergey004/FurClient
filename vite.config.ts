import react from '@vitejs/plugin-react';
import path from 'path';
import {defineConfig} from 'vite';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'src'),
      'react-native': 'react-native-web',
      'react-native-safe-area-context': path.resolve(__dirname, 'src/web-mocks/react-native-safe-area-context.ts'),
      'react-native-screens': path.resolve(__dirname, 'src/web-mocks/react-native-screens.ts'),
      'react-native-fast-image': path.resolve(__dirname, 'src/web-mocks/react-native-fast-image.ts'),
    },
    extensions: ['.web.tsx', '.web.ts', '.web.js', '.tsx', '.ts', '.js'],
  },
  define: {
    'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV || 'development'),
    __DEV__: JSON.stringify(false),
    global: 'globalThis',
  },
  build: {
    outDir: 'web-build',
  },
});
