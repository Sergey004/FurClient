import path from 'path';
import {defineConfig} from 'vite';

export default defineConfig({
  base: './',
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
  esbuild: {
    jsx: 'automatic',
    jsxImportSource: 'react',
    jsxDev: false,
  },
  define: {
    'process.env.NODE_ENV': JSON.stringify('production'),
    '__DEV__': 'false',
    '__REACT_DEVTOOLS_GLOBAL_HOOK__': 'false',
    'global': 'globalThis',
  },
  build: {
    outDir: 'web-build',
    emptyOutDir: true,
    minify: 'esbuild',
    modulePreload: false,
    cssCodeSplit: false,
    rollupOptions: {
      input: path.resolve(__dirname, 'index.web.tsx'),
      output: {
        entryFileNames: 'bundle.js',
        format: 'iife',
        inlineDynamicImports: true,
      },
    },
  },
});
