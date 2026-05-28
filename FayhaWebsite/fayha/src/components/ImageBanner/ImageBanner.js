import React from 'react';
import './ImageBanner.css';

const ImageBanner = ({ image, caption, height = 'medium' }) => {
  return (
    <figure className={`image-banner image-banner--${height}`}>
      <div
        className="image-banner__image"
        style={{ backgroundImage: `url(${image})` }}
        role="img"
        aria-label={caption || ''}
      ></div>
      {caption && (
        <figcaption className="image-banner__caption">{caption}</figcaption>
      )}
    </figure>
  );
};

export default ImageBanner;
