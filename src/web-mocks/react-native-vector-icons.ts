import React from 'react';
import {Text} from 'react-native';

function Icon({name, size, color, style}: any) {
  return React.createElement(Text, {style: [{fontSize: size || 24, color: color || '#000'}, style].flat()}, `[${name}]`);
}

export default Icon;
