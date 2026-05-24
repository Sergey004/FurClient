import React from 'react';
import {Image} from 'react-native';

export const Priority = {low: 'low', normal: 'normal', high: 'high'};
export const ResizeMode = {contain: 'contain', cover: 'cover', stretch: 'stretch', center: 'center'};

function FastImage(props: any) {
  return React.createElement(Image, props);
}

export default FastImage;
