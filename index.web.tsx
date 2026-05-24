import {AppRegistry} from 'react-native';
import App from './src/App';

if (typeof document !== 'undefined') {
  AppRegistry.registerComponent('FurClientRN', () => App);
  AppRegistry.runApplication('FurClientRN', {
    rootTag: document.getElementById('root'),
  });
}
